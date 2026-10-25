// Fictional, masked documents and the real-pipeline harness for the capture
// matrix (docs/research/capture-coverage.md). Shapes follow the parser_core
// corpora; names, numbers and amounts are invented.
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:excel/excel.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/email_ingestion/data/email_settings_store.dart';
import 'package:hisaab/features/email_ingestion/data/processed_email_repository_impl.dart';
import 'package:hisaab/features/email_ingestion/data/secure_email_credential_store.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_sync_report.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';
import 'package:hisaab/features/email_ingestion/domain/statement_attachments.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/manage_email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/sync_email.dart';
import 'package:hisaab/features/notification_ingestion/data/notification_settings_store.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/handle_app_notification.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart'
    as scan;
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:hisaab/features/statement_import/data/sheet_reader_impl.dart';
import 'package:hisaab/features/statement_import/data/statement_account_store_impl.dart';
import 'package:hisaab/features/statement_import/data/statement_password_store.dart';
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/password_source.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/usecases/apply_statement_accounts.dart';
import 'package:hisaab/features/statement_import/domain/usecases/import_statement.dart';
import 'package:parser_core/parser_core.dart' show Source;

import '../support/email_fakes.dart';
import '../support/pipeline_fakes.dart';
import '../support/test_env.dart';

/// When every message "arrived": 20 Oct 2026, 11:15 local.
final DateTime arrival = DateTime(2026, 10, 20, 11, 15);
final int arrivalMs = arrival.millisecondsSinceEpoch;

/// PDF stand-in: the "bytes" are `%PDF` + a tag, and [texts] maps the tag to
/// the text PdfBox would have returned. A tag in [locked] needs [password].
class TaggedPdf implements PdfTextReader {
  TaggedPdf(this.texts, {this.locked = const {}, this.password});
  final Map<String, String> texts;
  final Set<String> locked;
  final String? password;
  final tries = <String?>[];

  @override
  Future<String> extractText(Uint8List bytes, {String? password}) async {
    tries.add(password);
    final tag = utf8.decode(bytes.sublist(4));
    if (tag == 'scanned') throw const PdfReadException(PdfFailure.scanned);
    if (locked.contains(tag) && password != this.password) {
      throw PdfReadException(
        password == null
            ? PdfFailure.passwordRequired
            : PdfFailure.wrongPassword,
      );
    }
    final t = texts[tag];
    if (t == null) throw const PdfReadException(PdfFailure.unreadable);
    return t;
  }
}

class MemStatementFiles implements StatementFileStore {
  final files = <String, Uint8List>{};
  @override
  Future<String> save(String name, Uint8List bytes) async {
    files['/m/$name'] = bytes;
    return '/m/$name';
  }

  @override
  Future<Uint8List?> read(String path) async => files[path];
  @override
  Future<void> delete(String path) async => files.remove(path);
}

Uint8List pdfBytes(String tag) =>
    Uint8List.fromList([0x25, 0x50, 0x44, 0x46, ...utf8.encode(tag)]);

/// A real `.xlsx` workbook (read back by the real [SheetReaderImpl]).
Uint8List xlsxBytes(List<List<String>> rows) {
  final book = Excel.createExcel();
  final sheet = book[book.getDefaultSheet()!];
  for (final r in rows) {
    sheet.appendRow([for (final c in r) TextCellValue(c)]);
  }
  return Uint8List.fromList(book.encode()!);
}

/// The whole app pipeline over one in-memory database, with the native edges
/// (PDF text, IMAP, notification stream) faked.
class Pipeline {
  Pipeline({TaggedPdf? pdf}) : env = TestEnv() {
    holdings = HoldingRepositoryImpl(env.db);
    dues = CardDueRepositoryImpl(env.db);
    ingest = IngestMessage(
      ledger: env.txs,
      cardDues: dues,
      holdings: holdings,
    );
    this.pdf = pdf ?? TaggedPdf(const {});
    statements = ImportStatement(
      statements: StatementRepositoryImpl(env.db),
      savedPasswords: StatementPasswordStore(MemSecure()),
      pdf: this.pdf,
      sheets: const SheetReaderImpl(),
      files: MemStatementFiles(),
      ledger: env.txs,
      holdings: holdings,
      cardDues: dues,
      accounts: ApplyStatementAccounts(
        StatementAccountStoreImpl(env.db, clock: () => env.clock),
      ),
      passwordSource: () async => assemblePasswordSource(
        identity: null,
        profile: const UserProfile(),
        cardLast4s: const [],
        banks: const [],
        saved: const [],
      ),
      clock: () => env.clock,
    );
    notifications = HandleAppNotification(
      settings: NotificationSettingsStore(SettingsKeyValueStore(env.settings)),
      ingest: ingest,
    );
  }

  final TestEnv env;
  late final HoldingRepositoryImpl holdings;
  late final CardDueRepositoryImpl dues;
  late final IngestMessage ingest;
  late final TaggedPdf pdf;
  late final ImportStatement statements;
  late final HandleAppNotification notifications;
  final imap = FakeImap();

  Future<void> close() => env.close();

  Future<MessageIngestDetail> sms(String sender, String body, {int? at}) =>
      ingest.detail(
        InboxSms(
          sender: sender,
          body: body,
          receivedAt: at ?? arrivalMs,
          sentAt: at ?? arrivalMs,
        ),
      );

  /// One IMAP sync through the same wiring as `syncEmailProvider`.
  Future<EmailSyncReport> syncMails(List<RawEmail> mails) async {
    imap.mails = mails;
    final kv = SettingsKeyValueStore(env.settings);
    final settings = EmailSettingsStore(kv);
    final creds = SecureEmailCredentialStore(MemSecure());
    final sync = SyncEmail(
      imap: imap,
      settings: settings,
      credentials: creds,
      processed: ProcessedEmailRepositoryImpl(env.db),
      ingest: ({
        required sender,
        required body,
        required receivedAt,
        required messageId,
      }) async {
        final outcome = (await ingest.detail(
          InboxSms(sender: sender, body: body, receivedAt: receivedAt),
          source: Source.email,
          messageId: messageId,
        ))
            .outcome;
        if (outcome == scan.IngestOutcome.rejected &&
            await statements.readEmailBody(
              body: body,
              sender: sender,
              receivedAt: receivedAt,
            )) {
          return scan.IngestOutcome.skipped;
        }
        return outcome;
      },
      ingestStatement: ({
        required sender,
        required subject,
        required emailText,
        required receivedAt,
        required messageId,
        required index,
        required fileName,
        required bytes,
      }) async {
        final r = await statements.importEmailAttachment(
          PickedFile(name: fileName, bytes: bytes),
          EmailOrigin(
            messageId: messageId,
            index: index,
            sender: sender,
            subject: subject,
            receivedAt: receivedAt,
            emailText: emailText,
          ),
        );
        return switch (r) {
          ImportDone() => StatementFileOutcome.imported,
          ImportLocked() => StatementFileOutcome.locked,
          _ => StatementFileOutcome.skipped,
        };
      },
      now: () => DateTime(2026, 10, 21, 9),
    );
    await ManageEmailAccount(imap: imap, settings: settings, credentials: creds)
        .save(EmailAccount.forAddress('Me@Gmail.com'), 'abcd efgh ijkl mnop');
    return await sync();
  }

  RawEmail mail(
    String id,
    String from,
    String subject,
    String text, {
    List<EmailAttachment> attachments = const [],
    String? html,
  }) =>
      RawEmail(
        id: id,
        from: from,
        subject: subject,
        receivedAt: arrivalMs,
        plain: text,
        html: html,
        attachments: attachments,
      );

  /// Ledger rows, oldest first.
  Future<List<Tx>> txs() async {
    final rows = await env.db
        .customSelect(
          'SELECT amount_minor, type, bank_name, account_last4, account_kind, '
          'merchant, reference_number, category, '
          'needs_review, balance_minor, available_limit_minor FROM '
          'transactions ORDER BY id',
        )
        .get();
    return [
      for (final r in rows)
        Tx(
          amountMinor: r.read<int>('amount_minor'),
          type: r.read<String>('type'),
          bank: r.read<String>('bank_name'),
          last4: r.readNullable<String>('account_last4'),
          kind: r.read<String>('account_kind'),
          merchant: r.readNullable<String>('merchant'),
          ref: r.readNullable<String>('reference_number'),
          category: r.read<String>('category'),
          review: r.read<bool>('needs_review'),
          balanceMinor: r.readNullable<int>('balance_minor'),
          limitMinor: r.readNullable<int>('available_limit_minor'),
        ),
    ];
  }

  Future<Map<String, Object?>?> account(String bank, String last4) async {
    final r = await env.db.customSelect(
      'SELECT kind, account_type, latest_balance_minor, available_limit_minor, '
      'maturity_day FROM accounts WHERE bank_name = ? AND last4 = ?',
      variables: [Variable.withString(bank), Variable.withString(last4)],
    ).get();
    if (r.isEmpty) return null;
    return r.first.data;
  }
}

class Tx {
  const Tx({
    required this.amountMinor,
    required this.type,
    required this.bank,
    required this.last4,
    required this.kind,
    required this.merchant,
    required this.ref,
    required this.category,
    required this.review,
    required this.balanceMinor,
    required this.limitMinor,
  });
  final int amountMinor;
  final String type;
  final String bank;
  final String? last4;
  final String kind;
  final String? merchant;
  final String? ref;
  final String category;
  final bool review;
  final int? balanceMinor;
  final int? limitMinor;
  @override
  String toString() =>
      '$type $amountMinor $bank $last4 $kind $merchant $ref $category';
}

// ---------------------------------------------------------------- messages

const hdfcSms = 'VM-HDFCBK';
const hdfcDebitSms = 'UPDATE: INR 1,240.00 debited from HDFC Bank XX2779 on '
    '20-OCT-26. Info: UPI-SWIGGY-swiggy@icici. Avl bal:INR 23,410.00';
const hdfcDebitMail = 'Dear Customer,\n\nINR 1,240.00 has been debited from '
    'account **2779 to VPA swiggy@icici SWIGGY on 20-10-26.\n\nYour UPI '
    'transaction reference number is 529912345678.\n';
const hdfcAlertFrom = 'HDFC Bank InstaAlerts <alerts@hdfcbank.net>';

const phonepeEmailFrom = 'PhonePe <noreply@phonepe.com>';
const phonepeEmail = 'Hi Asha,\n\nPaid to Ravi Kumar\n₹250.00\nTransaction ID '
    'T2610201015000000001\nUTR 529912340001\nDebited from HDFC Bank XX2779\n';

const axisCardBill = 'Axis Bank Credit Card No. XX3190: Total payment due INR '
    '8,100.00. Minimum payment due INR 405.00. Due date 02-11-2026.';

const epfoSms = 'Dear Member, your passbook balance against '
    'MH/BAN/0012345/000/0001234 is Rs. 2,56,250/-. Contribution of Rs. 3,600/- '
    'for due month 092026 has been received.';

const npsHoldingSms = 'Total holding value Rs 4,56,789.00 as on 24-Sep-2026 '
    'for PRAN XXXXXXXX1234. -NPS Trust';
const npsContribSms = 'Dear Subscriber, Contribution of Rs.5000.00 for PRAN '
    'XXXXXXXX1234 has been credited to your Tier I account on 22-09-2026 and '
    'units allotted. -NPSCRA';

const hdfcFdSms = 'Your FD No. XXXXXXXX5678 for INR 1,00,000.00 has been '
    'booked on 20-10-2026 for 1 year at 7.10% p.a. Maturity date: 20-10-2027. '
    'Maturity amount INR 1,07,281.00. It will be auto renewed on maturity. '
    '-HDFC Bank';

const propelldSms = 'Dear Customer, EMI of Rs.12,345 for your loan a/c no. '
    'XXXX1234 has been received on 05-10-2026. Thank you. - Propelld';

const growwSipEmail = 'Hi A,\nYour SIP instalment of ₹5,000 for Parag Parikh '
    'Flexi Cap Fund Direct Growth has been processed successfully.\nAmount\n'
    '₹5,000.00\nUnits allotted\n61.234\nNAV\n₹81.6543\nNAV date\n19 Oct 2026\n'
    'Folio number\n12345678/90\nTeam Groww\n';

const indmoneySummaryEmail = '''
Hi A,
Your INDmoney portfolio summary
Mutual Funds: ₹1,23,456.00
Stocks: ₹45,000.00
''';

// -------------------------------------------------------------- statements

const cardStatement = '''
HDFC Bank Credit Card Statement
Card No: 4893 XXXX XXXX 5678
Statement Date 20/09/2026  Total Amount Due 12,345.00  Minimum Amount Due 620.00
Date Transaction Description Amount (in Rs.)
02/09/2026 AMAZON PAY INDIA MUMBAI 1,499.00
05/09/2026 SWIGGY BANGALORE 456.50
10/09/2026 PAYMENT RECEIVED - THANK YOU 8,000.00 Cr
12/09/2026 REFUND FLIPKART 299.00 Cr
''';

const bankStatement = '''
State Bank of India  Account Statement  A/c No XXXXXXX1234
Date Narration Debit Credit Balance
Opening Balance 50,000.00
01-09-2026 UPI/526812345678/SWIGGY 450.00 49,550.00
03-09-2026 NEFT SALARY ACME CORP 75,000.00 1,24,550.00
05-09-2026 ATM WDL MUMBAI 2,000.00 1,22,550.00
''';

const casCams = '''
Consolidated Account Statement
Folio No: 1234567 / 89
128TSDGG-Axis Bluechip Fund - Direct Growth - ISIN: INF846K01EW2(Advisor: DIRECT)
Closing Unit Balance: 123.456 NAV on 30-Sep-2026: INR 45.67 Total Cost Value: 5,000.00 Market Value on 30-Sep-2026: INR 5,638.12
P8DG-Parag Parikh Flexi Cap Fund - Direct Plan Growth - ISIN: INF879O01027(Advisor: DIRECT)
Closing Unit Balance: 1,000.000 NAV on 30-Sep-2026: INR 80.10 Total Cost Value: 60,000.00 Market Value on 30-Sep-2026: INR 80,100.00
''';

const casCdsl = '''
CDSL
Consolidated Account Statement
Statement for the period from 01-09-2026 to 30-09-2026
Holdings as on 30-09-2026
DP Name : EXAMPLE BROKING LIMITED   BO ID : 1208160012345678
HOLDING STATEMENT AS ON 30-09-2026
ISIN Security Current Bal. Frozen Bal. Pledge Bal. Pledge Setup Bal. Free Bal. Lock-in Bal. Earmarked Bal. Market Price / Face Value Value (₹)
INE002A01018 RELIANCE INDUSTRIES LIMITED#EQUITY SHARES 10.000 -- -- -- 10.000 -- -- 2,950.25 29,502.50
INF204KB14I2 NIPPON INDIA ETF NIFTY 50 BEES 100.000 -- -- -- 100.000 -- -- 285.40 28,540.00
Portfolio Value ₹ 58,042.50
''';

const npsStatement = '''
NPS Transaction Statement for Tier I Account
Protean eGov Technologies Limited - Central Recordkeeping Agency
PRAN : 110012341234
Subscriber Name : A SHARMA
Statement Date : 24-Sep-2026
Holdings as on 24-Sep-2026
Current Valuation Summary
Total Contribution (Rs) Total Withdrawal (Rs) Total Notional Gain/Loss (Rs) Value of your Holdings (Investment) as on 24-Sep-2026 (in Rs) Return on investment (XIRR)
3,50,000.00 0.00 1,06,789.12 4,56,789.12 10.25%
Investment Details - Scheme Wise Summary
Scheme Name Total Units NAV (Rs) Value at NAV (Rs)
SBI PENSION FUND SCHEME E - TIER I 4,000.0000 50.0000 2,00,000.00
LIC PENSION FUND SCHEME C - TIER I 6,000.0000 30.0000 1,80,000.00
HDFC PENSION FUND SCHEME G - TIER I 2,000.0000 38.3945 76,789.12
''';

const epfPassbook = '''
Employees' Provident Fund Organisation, India
Member Passbook
Establishment ID/Name MHBAN0012345000 / ACME SOFTWARE PVT LTD
Member ID/Name MHBAN00123450000001234 / A SHARMA
UAN 100123451234
Wage Month Transaction Date Transaction Type Particulars EPF Wages EPS Wages Employee Share Employer Share Pension Contribution
OB Int. Updated upto 31/03/2026 1,20,000 85,000 30,000
Apr-2026 15-05-2026 CR Cont. For Due-Month 052026 15,000 15,000 1,800 550 1,250
Int. Updated upto 31/03/2026 9,000 2,700 0
Total Contributions for the year [2026] 3,600 1,100 2,500
Closing Balance as on 30/09/2026 1,34,400 89,350 32,500
''';

const ppfStatement = '''
State Bank of India
Public Provident Fund Account Statement
PPF Account No: 00000012345673456
Statement Period 01-04-2026 to 24-09-2026
Date Description Debit Credit Balance
01-04-2026 Opening Balance 2,33,333.00
05-04-2026 BY TRANSFER FROM SB 10,000.00 2,43,333.00
05-09-2026 BY TRANSFER FROM SB 12,345.00 2,55,678.00
''';

const fdAdvice = '''
ICICI Bank
Fixed Deposit Advice
Deposit Account No: XXXXXXXX8899
Deposit Amount: 2,50,000.00
Rate of Interest: 7.20% p.a.
Date of Deposit: 20-09-2026
Maturity Date: 20-09-2028
Maturity Amount: 2,88,945.00
Maturity Instruction: Credit to my savings account
''';

const growwStocksPdf = '''
Groww
Stocks Holdings Statement
Holdings as on 24-Sep-2026
Stock Name Quantity Average Buy Price Buy Value Closing Price Closing Value Unrealised P&L
Reliance Industries 10 2,500.00 25,000.00 2,950.25 29,502.50 4,502.50
''';

/// Zerodha-style holdings CSV (Kite console export shape).
const zerodhaCsv = 'Instrument,Qty.,Avg. cost,LTP,Cur. val,P&L,Net chg.,Day '
    'chg.\r\n'
    'INFY,10,1500.00,1620.50,16205.00,1205.00,8.03%,0.50%\r\n'
    'NIFTYBEES,100,250.00,262.10,26210.00,1210.00,4.84%,0.10%\r\n';

/// Groww-style mutual fund holdings sheet rows.
const growwHead = [
  'Scheme Name', 'AMC', 'Category', 'Sub-category', 'Folio No.', 'Source', //
  'Units', 'Invested Value', 'Current Value', 'Returns', 'XIRR',
];
const growwRows = [
  [
    'Alpha Bluechip Fund Direct Growth',
    'Alpha Mutual Fund',
    'Equity',
    'Large Cap',
    '10203040',
    'Groww',
    '120.5',
    '12000',
    '13450.25',
    '1450.25',
    '9.1%',
  ],
  [
    'Beta Gold Fund Direct Growth',
    'Beta Mutual Fund',
    'Commodities',
    'Gold',
    '900011122233',
    'Groww',
    '80.25',
    '4000',
    '4810.4',
    '810.4',
    '18.2%',
  ],
];
List<List<String>> growwSheet() => [
      ['HOLDINGS AS ON 2026-10-06'],
      [],
      growwHead,
      ...growwRows,
    ];

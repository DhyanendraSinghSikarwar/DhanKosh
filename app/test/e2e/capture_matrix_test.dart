// Capture matrix: what the real app pipeline records from each kind of input.
// Everything after the native edge is real (parsers, ingest, dedup, ledger,
// holdings, card dues, statement import, IMAP sync wiring) over an in-memory
// database. Native PdfBox text, IMAP and the notification stream are faked.
// Evidence for docs/research/capture-coverage.md. Data is fictional.
// FR-02-*, FR-03-*, FR-04-*, FR-05-*, FR-06-*, FR-07-*, FR-14-06, FR-16-*.
// ignore_for_file: missing_whitespace_between_adjacent_strings, cascade_invocations
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/email_ingestion/domain/statement_attachments.dart';
import 'package:hisaab/features/notification_ingestion/data/notification_settings_store.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:parser_core/parser_core.dart'
    show IndianBanks, Money, ParserRegistry, TransactionType;

import '../../packages/parser_core/test/support/corpus.dart' as corpus;
import 'fixtures.dart';

void main() {
  late Pipeline p;
  tearDown(() => p.close());

  Future<void> enableNotifications() => NotificationSettingsStore(
        SettingsKeyValueStore(p.env.settings),
      ).setEnabled(enabled: true);

  AppNotification notif(String pkg, List<String> parts) => AppNotification(
        packageName: pkg,
        key: 'k-${parts.join().hashCode}',
        postTime: arrivalMs,
        parts: parts,
      );

  Future<ImportResult> importPdf(String tag, String text, {String? name}) {
    p = Pipeline(pdf: TaggedPdf({tag: text}));
    return p.statements(
      PickedFile(name: name ?? '$tag.pdf', bytes: pdfBytes(tag)),
    );
  }

  // ------------------------------------------------------------------ (a)
  group('a1 bank and card SMS: the ten corpus banks end to end', () {
    for (final entry in corpus.allCorpora.entries) {
      test('${entry.key}: every sample is stored or rejected as expected',
          () async {
        p = Pipeline();
        var accepted = 0;
        for (final s in entry.value) {
          final at = arrivalMs;
          final d = await p.ingest.detail(
            InboxSms(
              sender: s.sender,
              body: s.body,
              receivedAt: at,
              sentAt: at,
            ),
            source: s.source,
          );
          final tx = d.parse.transaction;
          final label = s.label;
          if (s.expect == null) {
            expect(tx, isNull, reason: label);
            continue;
          }
          final e = s.expect!;
          expect(tx, isNotNull, reason: label);
          expect(tx!.amountMinor, Money.parse(e.amount)!.minor, reason: label);
          expect(tx.type, e.type, reason: label);
          expect(tx.accountLast4, e.last4, reason: label);
          expect(d.outcome, isNot(IngestOutcome.rejected), reason: label);
          accepted++;
        }
        final rows = await p.txs();
        expect(rows, isNotEmpty);
        expect(rows.length, lessThanOrEqualTo(accepted));
        expect(rows.every((r) => r.amountMinor > 0), isTrue);
      });
    }

    test('SMS and email of the same payment are one ledger row', () async {
      p = Pipeline();
      final first = await p.sms(hdfcSms, hdfcDebitSms);
      expect(first.outcome, IngestOutcome.inserted);
      final r = await p.syncMails([
        p.mail('imap:<a@x>', hdfcAlertFrom, 'Alert', hdfcDebitMail),
      ]);
      expect(r.emails, 1);
      final rows = await p.txs();
      expect(rows, hasLength(1), reason: '$rows');
      expect(rows.single.amountMinor, 124000);
      expect(rows.single.type, 'DEBIT');
      expect(rows.single.last4, '2779');
      expect(rows.single.merchant, 'Swiggy');
      expect(rows.single.balanceMinor, 2341000);
    });

    test('credit card spend is a card row with the available limit', () async {
      p = Pipeline();
      await p.sms(
        hdfcSms,
        'Rs.349.00 spent via HDFC Bank Card xx5678 at UBER INDIA on '
        '2026-10-20:11:01:45 Avl Lmt: Rs 1,23,456.00',
      );
      final t = (await p.txs()).single;
      expect(t.kind, 'CARD');
      expect(t.last4, '5678');
      expect(t.amountMinor, 34900);
      expect(t.limitMinor, 12345600);
      expect(t.balanceMinor, isNull);
    });
  });

  group('a2 listed banks beyond the ten parsers', () {
    test('every listed bank sender is accepted and a debit is stored',
        () async {
      p = Pipeline();
      final registry = ParserRegistry.standard();
      var n = 0;
      for (final b in IndianBanks.all) {
        if (b.headers.isEmpty) continue;
        final sender = 'VM-${b.headers.first}';
        if (registry.resolve(sender) == null) continue;
        final d = await p.sms(
          sender,
          'Rs.${510 + n}.00 debited from A/c XX4321 on 20-10-26 by UPI Ref '
          '${529900000000 + n}. Avl Bal Rs.9,999.00',
        );
        expect(d.parse.transaction, isNotNull, reason: b.name);
        expect(d.parse.transaction!.bankName, isNotEmpty, reason: b.name);
        n++;
      }
      expect(n, greaterThan(30));
      expect(await p.txs(), hasLength(n));
    });
  });

  group('a3 payment-app receipts and notifications', () {
    test('PhonePe email and the bank SMS for it are one row (UPI ref)',
        () async {
      p = Pipeline();
      await p.sms(
        hdfcSms,
        'Rs.250.00 debited from a/c **2779 on 20-10-26 to VPA ravi@ybl'
        '(UPI Ref No 529912340001).',
      );
      await p.syncMails([
        p.mail(
          'imap:<pp@x>',
          phonepeEmailFrom,
          'Payment successful',
          phonepeEmail,
        ),
      ]);
      final rows = await p.txs();
      expect(rows, hasLength(1), reason: '$rows');
      expect(rows.single.amountMinor, 25000);
      expect(rows.single.ref, '529912340001');
    });

    for (final c in <(String, String, List<String>, int, String)>[
      (
        'PhonePe',
        'com.phonepe.app',
        ['Payment successful', '₹250 paid to Ravi Kumar'],
        25000,
        'DEBIT'
      ),
      (
        'Google Pay',
        'com.google.android.apps.nbu.paisa.user',
        ['Paid ₹180', 'to Chai Point'],
        18000,
        'DEBIT'
      ),
      (
        'Paytm',
        'net.one97.paytm',
        ['Paid ₹99 to Metro Card', 'Paid successfully'],
        9900,
        'DEBIT'
      ),
      (
        'PhonePe received',
        'com.phonepe.app',
        ['Received ₹500', 'from Asha Rao'],
        50000,
        'CREDIT'
      ),
    ]) {
      test('${c.$1} notification is stored', () async {
        p = Pipeline();
        await enableNotifications();
        final r = await p.notifications(notif(c.$2, c.$3));
        expect(
          r.outcome,
          IngestOutcome.inserted,
          reason: '${r.skip} ${r.reason}',
        );
        final t = (await p.txs()).single;
        expect(t.amountMinor, c.$4);
        expect(t.type, c.$5);
      });
    }

    test('notification is ignored while the source toggle is off', () async {
      p = Pipeline();
      final r = await p.notifications(
        notif('com.phonepe.app', ['Paid ₹250', 'to Ravi Kumar']),
      );
      expect(r.skip, NotificationSkip.settingOff);
      expect(await p.txs(), isEmpty);
    });

    test('unwatched app and failed payment are skipped', () async {
      p = Pipeline();
      await enableNotifications();
      final a = await p.notifications(
        notif('com.example.shopping', ['Paid ₹250', 'to Ravi Kumar']),
      );
      expect(a.skip, NotificationSkip.notWatched);
      final b = await p.notifications(
        notif('com.phonepe.app', ['Payment failed', '₹250 to Ravi Kumar']),
      );
      expect(b.outcome, isNull);
      expect(await p.txs(), isEmpty);
    });

    test('WhatsApp chat text is not a payment', () async {
      p = Pipeline();
      await enableNotifications();
      final r = await p.notifications(
        notif('com.whatsapp', ['Ravi', 'bro i paid 500 for lunch yesterday']),
      );
      expect(r.outcome, isNull);
      expect(await p.txs(), isEmpty);
    });

    test('an app notification never records a card bill', () async {
      p = Pipeline();
      await enableNotifications();
      await p.notifications(notif('com.axis.mobile', [axisCardBill]));
      expect(await p.dues.notices(), isEmpty);
    });
  });

  // -------------------------------------------------------------- negatives
  group('negative cases are rejected', () {
    final cases = <String, String>{
      'OTP': '482913 is the One Time Password (OTP) for your transaction of '
          'Rs. 2,499.00 at MYNTRA on HDFC Bank Card ending 5678. Do not share.',
      'promo': 'HDFC Bank: Get a pre-approved personal loan up to Rs 10,00,000 '
          'at 10.5%. Click http://hdfc.example/loan to apply. T&C apply.',
      'failed': 'Transaction of Rs.500.00 on HDFC Bank Card x5678 at FLIPKART '
          'has been declined due to insufficient balance.',
      'future': 'Rs.599.00 will be debited from HDFC Bank A/c XX1234 on '
          '01-11-26 towards NETFLIX mandate.',
    };
    cases.forEach((name, body) {
      test('$name SMS leaves the ledger empty', () async {
        p = Pipeline();
        final d = await p.sms(hdfcSms, body);
        expect(d.parse.transaction, isNull);
        expect(await p.txs(), isEmpty);
      });
    });

    test('unknown sender is not accepted', () async {
      p = Pipeline();
      expect(p.ingest.accepts('VM-ZZZZZZ'), isFalse);
      final d = await p.sms('VM-ZZZZZZ', hdfcDebitSms);
      expect(d.outcome, IngestOutcome.rejected);
      expect(await p.txs(), isEmpty);
    });

    test('a bank mail with no payment in it is marked rejected', () async {
      p = Pipeline();
      final r = await p.syncMails([
        p.mail(
          'imap:<n@x>',
          hdfcAlertFrom,
          'Newsletter',
          'Dear Customer, explore our new savings offers this festive season.',
        ),
      ]);
      expect(r.emails, 1);
      expect(r.inserted, 0);
      expect(await p.txs(), isEmpty);
    });
  });

  // ------------------------------------------------------------------ (b)
  group('b statements: files by import and by mail', () {
    test('credit card statement PDF: rows, due notice, card limit', () async {
      final r = await importPdf('card', cardStatement) as ImportDone;
      expect(r.added + r.merged + r.review, 4);
      expect(r.cardNotice, isTrue);
      final rows = await p.txs();
      expect(rows, hasLength(r.added + r.review));
      expect(rows.where((t) => t.amountMinor == 149900), hasLength(1));
      expect(rows.every((t) => t.last4 == '5678' && t.kind == 'CARD'), isTrue);
      expect(
        rows.where((t) => t.type == 'CREDIT').map((t) => t.amountMinor),
        [29900],
      );
      expect(rows.where((t) => t.type == 'TRANSFER'), hasLength(1));
      final due = (await p.dues.notices()).single;
      expect(due.totalDueMinor, 1234500);
      expect(due.minDueMinor, 62000);
      expect(due.last4, '5678');
    });

    test('bank account statement PDF: direction from running balance',
        () async {
      final r = await importPdf('bank', bankStatement) as ImportDone;
      expect(r.added, 3);
      final rows = await p.txs();
      expect(rows.map((t) => (t.type, t.amountMinor)), [
        ('DEBIT', 45000),
        ('CREDIT', 7500000),
        ('DEBIT', 200000),
      ]);
      expect(rows.every((t) => t.last4 == '1234'), isTrue);
      final acc = await p.account('State Bank of India', '1234') ??
          await p.account('SBI', '1234');
      expect(acc, isNotNull);
      expect(acc!['latest_balance_minor'], 12255000);
    });

    test('statement row equal to an earlier SMS merges, not duplicates',
        () async {
      p = Pipeline(pdf: TaggedPdf({'bank': bankStatement}));
      await p.sms(
        'VM-SBIUPI',
        'Dear UPI user A/C X1234 debited by 450.0 on date 01Sep26 trf to '
            'SWIGGY Refno 526812345678. If not u? call 1800111109. -SBI',
        at: DateTime(2026, 9, 1, 10).millisecondsSinceEpoch,
      );
      final r = await p.statements(
        PickedFile(name: 'bank.pdf', bytes: pdfBytes('bank')),
      ) as ImportDone;
      expect(r.merged, 1, reason: '$r');
      expect(await p.txs(), hasLength(3));
    });

    test('same file twice is refused', () async {
      await importPdf('card', cardStatement);
      final again = await p.statements(
        PickedFile(name: 'card.pdf', bytes: pdfBytes('card')),
      );
      expect(again, isA<ImportAlreadyDone>());
    });

    test('password-protected PDF is held LOCKED, nothing ledgered', () async {
      p = Pipeline(
        pdf: TaggedPdf(
          {'lk': cardStatement},
          locked: {'lk'},
          password: 'secret-pw',
        ),
      );
      final r = await p.statements(
        PickedFile(name: 'lk.pdf', bytes: pdfBytes('lk')),
      );
      expect(r, isA<ImportLocked>());
      expect(await p.txs(), isEmpty);
      final id = (r as ImportLocked).statementId;
      expect(await p.statements.unlock(id, 'secret-pw'), isA<ImportDone>());
      expect(await p.txs(), isNotEmpty);
    });

    test('scanned (image-only) PDF is unsupported', () async {
      p = Pipeline(pdf: TaggedPdf(const {}));
      final r = await p.statements(
        PickedFile(name: 's.pdf', bytes: pdfBytes('scanned')),
      );
      expect(r, isA<ImportUnsupported>());
      expect((r as ImportUnsupported).reason, UnsupportedReason.scanned);
      expect(await p.txs(), isEmpty);
    });

    test('legacy .xls is unsupported', () async {
      p = Pipeline();
      final r = await p.statements(
        PickedFile(
          name: 'st.xls',
          bytes: Uint8List.fromList(
            [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
          ),
        ),
      );
      expect(r, isA<ImportUnsupported>());
      expect((r as ImportUnsupported).reason, UnsupportedReason.xls);
    });

    test('bank statement as CSV is ingested', () async {
      p = Pipeline();
      const csv = 'HDFC BANK Ltd.,,Statement of account\r\n'
          'Account No :,50100012345678\r\n'
          'Date,Narration,Chq./Ref.No.,Value Dt,Withdrawal Amt.,Deposit Amt.,'
          'Closing Balance\r\n'
          '01/09/26,UPI-SWIGGY-swiggy@icici-ICIC0000001-123456789012,'
          '0000123456789012,01/09/26,450,,52340.5\r\n'
          '03/09/26,NEFT CR-ACME CORP-SALARY SEP,N123456,03/09/26,0,85000,'
          '137340.5\r\n';
      final r = await p.statements(
        PickedFile(name: 'st.csv', bytes: Uint8List.fromList(utf8.encode(csv))),
      ) as ImportDone;
      expect(r.added, 2);
      final rows = await p.txs();
      expect(
        rows.map((t) => (t.type, t.amountMinor)),
        [('DEBIT', 45000), ('CREDIT', 8500000)],
      );
    });

    test('bank statement as real XLSX is ingested', () async {
      p = Pipeline();
      final r = await p.statements(
        PickedFile(
          name: 'st.xlsx',
          bytes: xlsxBytes([
            ['HDFC BANK Ltd.', '', 'Statement of account'],
            ['Account No :', '50100012345678'],
            [
              'Date',
              'Narration',
              'Chq./Ref.No.',
              'Value Dt',
              'Withdrawal Amt.',
              'Deposit Amt.',
              'Closing Balance',
            ],
            [
              '01/09/26',
              'UPI-SWIGGY-swiggy@icici-ICIC0000001-123456789012',
              '0000123456789012',
              '01/09/26',
              '450',
              '',
              '52340.5',
            ],
            [
              '03/09/26',
              'NEFT CR-ACME CORP-SALARY SEP',
              'N123456',
              '03/09/26',
              '0',
              '85000',
              '137340.5',
            ],
          ]),
        ),
      ) as ImportDone;
      expect(r.added, 2);
    });

    test('statement PDF attached to a bank mail is imported once by sync',
        () async {
      p = Pipeline(pdf: TaggedPdf({'cardmail': cardStatement}));
      final m = p.mail(
        'imap:<st@x>',
        'HDFC Bank <emailstatements.cards@hdfcbank.net>',
        'Your HDFC Bank Credit Card Statement',
        'Please find your statement attached.',
        attachments: [
          EmailAttachment(name: 'stmt.pdf', bytes: pdfBytes('cardmail')),
        ],
      );
      final r = await p.syncMails([m]);
      expect(r.statements, 1);
      expect(await p.txs(), hasLength(4));
      expect(await p.dues.notices(), hasLength(1));
      final again = await p.syncMails([m]);
      expect(again.skipped, 1);
      expect(await p.txs(), hasLength(4));
    });

    test('statement mail from a sender outside the whitelist is not fetched',
        () async {
      p = Pipeline();
      final r = await p.syncMails([
        p.mail(
          'imap:<x@x>',
          'Random <a@random-shop.example>',
          'Hello',
          'Rs.250.00 debited from your account',
        ),
      ]);
      expect(r.emails, 0);
    });
  });

  // ------------------------------------------------------------------ (c)
  group('c mutual funds', () {
    test('CAMS CAS PDF text gives mutual fund holdings with value and cost',
        () async {
      final r = await importPdf('cas', casCams) as ImportDone;
      expect(r.holdings, 2);
      expect(r.added, 0);
      final hs = await p.holdings.list();
      expect(hs.every((h) => h.kind == HoldingKind.mutualFund), isTrue);
      final ppfas = hs.singleWhere((h) => h.name.contains('Parag'));
      expect(ppfas.valueMinor, 8010000);
      expect(ppfas.investedMinor, 6000000);
      expect(ppfas.units, closeTo(1000, 1e-9));
      expect(await p.txs(), isEmpty);
    });

    test('CAS re-read does not duplicate holdings', () async {
      await importPdf('cas', casCams);
      await p.statements.readAgain(1);
      expect(await p.holdings.list(), hasLength(2));
    });

    test('CAS attached to a CAMS mail is imported by sync', () async {
      p = Pipeline(pdf: TaggedPdf({'casmail': casCams}));
      final r = await p.syncMails([
        p.mail(
          'imap:<cas@x>',
          'CAMS <donotreply@camsonline.com>',
          'Consolidated Account Statement',
          'Attached.',
          attachments: [
            EmailAttachment(name: 'cas.pdf', bytes: pdfBytes('casmail')),
          ],
        ),
      ]);
      expect(r.statements, 1);
      expect(await p.holdings.list(), hasLength(2));
    });

    test('Groww mutual fund holdings XLSX (real workbook) gives MF and gold',
        () async {
      p = Pipeline();
      final r = await p.statements(
        PickedFile(name: 'groww.xlsx', bytes: xlsxBytes(growwSheet())),
      ) as ImportDone;
      expect(r.holdings, 2, reason: '$r');
      final hs = await p.holdings.list();
      final alpha = hs.singleWhere((h) => h.name.startsWith('Alpha'));
      expect(alpha.kind, HoldingKind.mutualFund);
      expect(alpha.valueMinor, 1345025);
      expect(alpha.investedMinor, 1200000);
      expect(
        hs.singleWhere((h) => h.name.startsWith('Beta')).kind,
        HoldingKind.gold,
      );
    });

    test('INDmoney portfolio summary mail records aggregate holdings',
        () async {
      p = Pipeline();
      final r = await p.syncMails([
        p.mail(
          'imap:<ind@x>',
          'INDmoney <noreply@indmoney.com>',
          'Your portfolio summary',
          indmoneySummaryEmail,
        ),
      ]);
      expect(r.emails, 1);
      final hs = await p.holdings.list();
      expect(hs.map((h) => h.valueMinor), contains(12345600), reason: '$hs');
    });

    test('LIMITATION: SIP / order confirmation mail records nothing', () async {
      // MfOrderParser exists in parser_core but no app code calls it, so a
      // Groww/INDmoney order mail neither adds a holding nor a transaction.
      p = Pipeline();
      final r = await p.syncMails([
        p.mail(
          'imap:<sip@x>',
          'Groww <noreply@groww.in>',
          'Your SIP instalment for Parag Parikh Flexi Cap Fund is successful',
          growwSipEmail,
        ),
      ]);
      expect(r.emails, 1);
      expect(await p.txs(), isEmpty);
      expect(await p.holdings.list(), isEmpty);
    });

    test('bank SMS for a SIP debit is an INVESTMENT row', () async {
      p = Pipeline();
      await p.sms(
        hdfcSms,
        'Rs.5000.00 debited from HDFC Bank A/c XX2779 on 20-10-26 towards '
        'SIP PARAG PARIKH FLEXI CAP FUND. UPI Ref 529912340777',
      );
      final rows = await p.txs();
      expect(rows, hasLength(1), reason: '$rows');
      expect(rows.single.amountMinor, 500000);
      expect(rows.single.type, 'INVESTMENT');
    });
  });

  // ------------------------------------------------------------------ (d)
  group('d stocks and ETFs', () {
    test('CDSL CAS gives a stock and an ETF by ISIN', () async {
      final r = await importPdf('cdsl', casCdsl) as ImportDone;
      expect(r.holdings, 2);
      final hs = await p.holdings.list();
      final rel = hs.singleWhere((h) => h.identifier == 'INE002A01018');
      expect(rel.kind, HoldingKind.stock);
      expect(rel.valueMinor, 2950250);
      final etf = hs.singleWhere((h) => h.identifier == 'INF204KB14I2');
      expect(etf.valueMinor, 2854000);
      expect(etf.kind, anyOf(HoldingKind.etf, HoldingKind.mutualFund));
    });

    test('Zerodha-style holdings CSV gives stocks', () async {
      p = Pipeline();
      final r = await p.statements(
        PickedFile(
          name: 'holdings.csv',
          bytes: Uint8List.fromList(utf8.encode(zerodhaCsv)),
        ),
      ) as ImportDone;
      expect(r.holdings, 2, reason: '$r');
      final hs = await p.holdings.list();
      final infy = hs.singleWhere((h) => h.name.toUpperCase().contains('INFY'));
      expect(infy.valueMinor, 1620500);
      expect(infy.investedMinor, 1500000);
      expect(infy.units, closeTo(10, 1e-9));
    });

    test('Groww stocks holdings PDF text', () async {
      final r = await importPdf('gstk', growwStocksPdf) as ImportDone;
      expect(r.holdings, 1);
      final h = (await p.holdings.list()).single;
      expect(h.kind, HoldingKind.stock);
      expect(h.valueMinor, 2950250);
      expect(h.investedMinor, 2500000);
    });

    test('LIMITATION: a trade contract note is not a holding source', () async {
      // Contract notes / order SMS from brokers are not parsed: only holdings
      // statements and sheets are.
      p = Pipeline();
      final d = await p.sms(
        'VM-ZERODH',
        'Order executed: BUY 10 INFY @ 1500.00 on 20-10-2026. -Zerodha',
      );
      expect(d.parse.transaction, isNull);
      expect(await p.holdings.list(), isEmpty);
    });
  });

  // ------------------------------------------------------------------ (e)
  group('e PF / EPF', () {
    test('EPFO SMS records an EPF holding, no transaction', () async {
      p = Pipeline();
      final d = await p.sms('VM-EPFOHO', epfoSms);
      expect(d.outcome, IngestOutcome.inserted);
      final h = (await p.holdings.list()).single;
      expect(h.kind, HoldingKind.epf);
      expect(h.valueMinor, 25625000);
      expect(h.identifier, 'EPF:MHBAN00123450000001234');
      expect(await p.txs(), isEmpty);
    });

    test('passbook PDF updates the same EPF holding (one key)', () async {
      p = Pipeline(pdf: TaggedPdf({'epf': epfPassbook}));
      await p.sms('VM-EPFOHO', epfoSms);
      final r = await p.statements(
        PickedFile(name: 'passbook.pdf', bytes: pdfBytes('epf')),
      ) as ImportDone;
      expect(r.holdings, 1);
      final hs = await p.holdings.list();
      expect(hs, hasLength(1));
      expect(hs.single.valueMinor, 25625000);
      expect(await p.txs(), isEmpty);
    });
  });

  // ------------------------------------------------------------------ (f)
  group('f NPS', () {
    test('holding-value SMS records an NPS holding', () async {
      p = Pipeline();
      await p.sms('JD-NPSTRS', npsHoldingSms);
      final h = (await p.holdings.list()).single;
      expect(h.kind, HoldingKind.nps);
      expect(h.valueMinor, 45678900);
      expect(h.identifier, 'NPS:1234');
    });

    test('statement PDF text gives the Tier I holding', () async {
      final r = await importPdf('nps', npsStatement) as ImportDone;
      expect(r.holdings, 1);
      final h = (await p.holdings.list()).single;
      expect(h.kind, HoldingKind.nps);
      expect(h.valueMinor, 45678912);
      expect(h.investedMinor, 35000000);
    });

    test('LIMITATION: a contribution SMS alone records nothing', () async {
      // InvestmentParser.npsContribution exists but is not called by ingest.
      p = Pipeline();
      final d = await p.sms('AX-NPSCRA', npsContribSms);
      expect(d.outcome, IngestOutcome.rejected);
      expect(await p.holdings.list(), isEmpty);
      expect(await p.txs(), isEmpty);
    });
  });

  // ------------------------------------------------------------------ (g)
  group('g deposits and loans', () {
    test('FD advice PDF opens an FD account with maturity, no transactions',
        () async {
      final r = await importPdf('fd', fdAdvice) as ImportDone;
      expect(r.deposits, 1);
      expect(await p.txs(), isEmpty);
      final a = await p.account('ICICI Bank', '8899');
      expect(a, isNotNull);
      expect(a!['account_type'], anyOf('FD', 'fd'));
      expect(a['latest_balance_minor'], 25000000);
      expect(a['maturity_day'], isNotNull);
    });

    test('PPF statement PDF updates a PPF account balance', () async {
      final r = await importPdf('ppf', ppfStatement) as ImportDone;
      expect(r.deposits, 1);
      expect(await p.txs(), isEmpty);
      final a = await p.account('SBI', '3456');
      expect(a, isNotNull);
      expect(a!['account_type'], anyOf('PPF', 'ppf'));
      expect(a['latest_balance_minor'], 25567800);
    });

    test('LIMITATION: FD booking SMS is not recorded as a deposit', () async {
      // registry.loanStatus parses it, but IngestMessage never calls it:
      // only statements feed deposit and loan accounts.
      p = Pipeline();
      final d = await p.sms(hdfcSms, hdfcFdSms);
      expect(d.parse.transaction, isNull);
      expect(await p.txs(), isEmpty);
      expect(await p.account('HDFC Bank', '5678'), isNull);
    });

    test('lender EMI SMS is a debit on the loan account (EMI category)',
        () async {
      p = Pipeline();
      await p.sms('VM-PROPLD', propelldSms);
      final t = (await p.txs()).single;
      expect(t.amountMinor, 1234500);
      expect(t.type, 'DEBIT');
      expect(t.bank, 'Propelld');
      expect(t.last4, '1234');
      expect(t.category, isNot('other'));
    });

    test('lender EMI mail is a debit too', () async {
      p = Pipeline();
      await p.syncMails([
        p.mail(
            'imap:<emi@x>',
            'Propelld <noreply@propelld.com>',
            'EMI received',
            'Dear Student,\nWe have received your EMI payment of Rs. 8,500.00 '
                'towards your loan account PRPL0012345 on 05-10-2026.\nThank '
                'you,\nTeam Propelld'),
      ]);
      final t = (await p.txs()).single;
      expect(t.amountMinor, 850000);
      expect(t.last4, '2345');
    });

    test('LIMITATION: loan EMI reminder is not a transaction', () async {
      p = Pipeline();
      final d = await p.sms(
        'VM-PROPLD',
        'Your EMI of Rs 8,500 towards Loan Account No. PROP12345 is due on '
            '05-Nov-2026. Please keep sufficient balance. - Propelld',
      );
      expect(d.parse.transaction, isNull);
      expect(await p.txs(), isEmpty);
    });
  });

  // ------------------------------------------------------------------ (h)
  group('h card due notices', () {
    test('Axis bill SMS is a notice with total, minimum and due date',
        () async {
      p = Pipeline();
      final d = await p.sms('VM-AXISBK', axisCardBill);
      expect(d.outcome, IngestOutcome.inserted);
      final n = (await p.dues.notices()).single;
      expect(n.totalDueMinor, 810000);
      expect(n.minDueMinor, 40500);
      expect(n.last4, '3190');
      expect(
        n.dueEpochDay,
        DateTime.utc(2026, 11, 2).millisecondsSinceEpoch ~/ 86400000,
      );
      expect(await p.txs(), isEmpty);
    });

    test('bill mail and statement for the same card both record notices',
        () async {
      p = Pipeline(pdf: TaggedPdf({'card': cardStatement}));
      await p.sms('VM-AXISBK', axisCardBill);
      await p.statements(
        PickedFile(name: 'card.pdf', bytes: pdfBytes('card')),
      );
      final notices = await p.dues.notices();
      expect(notices.map((n) => n.last4), containsAll(['3190', '5678']));
    });

    test('same bill SMS twice is one notice', () async {
      p = Pipeline();
      await p.sms('VM-AXISBK', axisCardBill);
      await p.sms('VM-AXISBK', axisCardBill);
      expect(await p.dues.notices(), hasLength(1));
    });

    test('card payment received SMS is a payment, not a spend', () async {
      p = Pipeline();
      await p.sms(
        'VM-AXISBK',
        'Payment of INR 8,100.00 received towards Axis Bank Credit Card '
            'XX3190 on 20-10-2026. Thank you.',
      );
      final rows = await p.txs();
      expect(rows.where((t) => t.type == 'DEBIT'), isEmpty);
      expect(rows.single.type, 'TRANSFER');
      expect(rows.single.amountMinor, 810000);
      expect(rows.single.kind, 'CARD');
    });
  });

  test('fixtures only use TransactionType names the ledger stores', () {
    expect(
      TransactionType.values.map((e) => e.name),
      containsAll(['debit', 'credit', 'transfer', 'investment']),
    );
  });
}

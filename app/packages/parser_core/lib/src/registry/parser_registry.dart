import 'package:parser_core/src/bank/banks.dart';
import 'package:parser_core/src/bank/base_bank_parser.dart';
import 'package:parser_core/src/bank/generic_bank_parser.dart';
import 'package:parser_core/src/bank/indian_banks.dart';
import 'package:parser_core/src/bank/lender_parser.dart';
import 'package:parser_core/src/bank/loan_status.dart';
import 'package:parser_core/src/bank/payment_app_parser.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/parse_result.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/registry/bank_parser.dart';
import 'package:parser_core/src/registry/sender_keys.dart';
import 'package:parser_core/src/statement/card_due.dart';
import 'package:parser_core/src/text/rx.dart';

/// Maps a sender to its parser through a hash map. The generic parser handles
/// bank-looking senders nobody claims (FR-06-03, FR-06-04).
class ParserRegistry {
  /// Builds a registry; throws [ArgumentError] when two parsers claim one key.
  ParserRegistry(this.parsers, [this._fallback]) {
    for (final p in parsers) {
      for (final k in p.senderKeys) {
        final previous = _byKey[k];
        if (previous != null && !identical(previous, p)) {
          throw ArgumentError(
            'Sender key $k claimed by ${previous.bankName} and ${p.bankName}',
          );
        }
        _byKey[k] = p;
      }
    }
  }

  /// The registry with every bank, lender and payment-app parser.
  factory ParserRegistry.standard([
    ParserConfig config = const ParserConfig(),
  ]) {
    final core = <BankParser>[
      HdfcBankParser(config),
      IciciBankParser(config),
      SbiParser(config),
      AxisBankParser(config),
      KotakBankParser(config),
      IdfcFirstBankParser(config),
      YesBankParser(config),
      BankOfBarodaParser(config),
      PnbParser(config),
      AuBankParser(config),
      ...Lenders.parsers(config),
      PaymentAppParser(config),
    ];
    // The listed banks (Central Bank, Bank of Maharashtra, Canara,
    // co-operative banks ...) never take a sender code or mail domain that a
    // parser above already owns, so two parsers can never claim one sender.
    final taken = <String>{for (final p in core) ...p.senderKeys};
    final listed = <BankParser>[];
    for (final bank in IndianBanks.all) {
      final headers =
          bank.headers.where((h) => !taken.contains(h.toUpperCase())).toSet();
      final domains =
          bank.domains.where((d) => !taken.contains(d.toLowerCase())).toSet();
      taken
        ..addAll(headers.map((h) => h.toUpperCase()))
        ..addAll(domains.map((d) => d.toLowerCase()));
      if (headers.isEmpty && domains.isEmpty) continue;
      listed.add(
        ListedBankParser(ListedBank(bank.name, headers, domains), config),
      );
    }
    return ParserRegistry([...core, ...listed], GenericBankParser(config));
  }

  /// The parsers in priority order.
  final List<BankParser> parsers;
  final BankParser? _fallback;
  final Map<String, BankParser> _byKey = {};

  /// The parser a dedicated entry claims for [sender], or null.
  BankParser? resolve(String sender) {
    for (final key in SenderKeys.candidates(sender)) {
      final p = _byKey[key];
      if (p != null) return p;
    }
    return null;
  }

  /// True only for senders a dedicated parser claims.
  bool isKnownSender(String sender) => resolve(sender) != null;

  /// SMS pre-filter: senders a dedicated parser claims, plus bank and
  /// card-issuer senders the generic parser takes. Looks at the sender only,
  /// so it is cheap enough to run on every inbox row.
  bool accepts(String sender) =>
      isKnownSender(sender) || (_fallback?.canHandle(sender, '') ?? false);

  BankParser? _parserFor(String sender, String body) {
    final p = resolve(sender);
    if (p != null) return p;
    final f = _fallback;
    return f != null && f.canHandle(sender, body) ? f : null;
  }

  /// What a lender's message says about a loan when it is not a payment
  /// (disbursal, outstanding, reminder), or what a bank's message says about an
  /// FD, RD or PPF account (booking, renewal, maturity, balance).
  LoanStatus? loanStatus(
    String body,
    String sender,
    int timestamp,
    Source source,
  ) {
    final parser = _parserFor(sender, body);
    if (parser is LenderParser) return parser.status(body, timestamp, source);
    if (parser is BaseBankParser) {
      return parser.depositStatus(body, sender, timestamp, source);
    }
    return null;
  }

  /// What a card issuer's "statement generated / bill due" message says (total
  /// and minimum due, due date), or the payment it acknowledges. Not a
  /// transaction: the reminder rules reject these as transactions.
  CardDue? cardDue(String body, String sender, int timestamp) {
    final parser = _parserFor(sender, body);
    if (parser is LenderParser) return null;
    final bank =
        parser == null || parser is GenericBankParser ? null : parser.bankName;
    return CardDueParser.parse(body, bank, timestamp);
  }

  /// Parses one message, with the reason when it is not a transaction.
  ParseResult parseDetailed(
    String body,
    String sender,
    int timestamp,
    Source source,
  ) {
    final parser = _parserFor(sender, body);
    if (parser == null) return const NotATransaction('unknown sender');
    return parser.parseDetailed(body, sender, timestamp, source);
  }

  /// The transaction in a message, or null.
  ParsedTransaction? parse(
    String body,
    String sender,
    int timestamp,
    Source source,
  ) =>
      parseDetailed(body, sender, timestamp, source).transaction;

  /// Domains for the default email sender whitelist: banks, plus the senders of
  /// investment and card statements.
  List<String> get defaultEmailSenders => {
        for (final p in parsers.whereType<BaseBankParser>()) ...p.emailSenders,
        ...statementSenders,
      }.toList();

  /// CAS and broker statements (CAMS, KFintech, NSDL, CDSL, brokers), EPFO, and
  /// card issuers without a parser.
  static const List<String> statementSenders = [
    'camsonline.com', 'kfintech.com', 'karvy.com', 'nsdl.co.in', 'nsdl.com',
    'cdslindia.com', 'cdslstatement.com',
    'icicidirect.com', 'icicisecurities.com', 'hdfcsec.com',
    'kotaksecurities.com', 'indmoney.com', 'zerodha.com', 'zerodha.net',
    'groww.in', 'upstox.com', 'angelone.in', 'dhan.co', 'kuvera.in',
    'epfindia.gov.in', 'sbicard.com', 'americanexpress.co.in', 'aexp.com',
    'rblbank.com', 'indusind.com', 'hsbc.co.in',
    'sc.com', 'onecard.in', 'federalbank.co.in', 'aubank.in',
    'getonecard.app', 'slicepay.in', 'sliceit.com', 'jupiter.money',
    'fi.money', 'scapia.cards', 'uni.cards', 'bobfinancial.com',
    'bajajfinserv.in', 'kfintech.net', 'camsonline.co.in', 'indusind.bank.in',
    'canarabank.com', 'unionbankofindia.co.in',
    'citibank.com', 'dbs.com', 'paytmbank.com', 'nps-proteantech.in',
    'proteantech.in',
    'cdslindia.co.in', 'cdsl.co.in', 'npstrust.org.in', 'npscra.nsdl.co.in',
    'kfintech-cra.com', 'camsnps.com',
    'epfo.gov.in', 'umang.gov.in',
    // Lenders (NBFC and fintech): EMI receipts and loan statements.
    'propelld.com', 'adityabirlacapital.com', 'abcd.adityabirlacapital.com',
    'tatacapital.com', 'credila.com', 'avanse.com',
    'incred.com', 'smfgindiacredit.com', 'homecredit.co.in', 'kreditbee.in',
    'navi.com', 'poonawallafincorp.com', 'hdbfs.com',
    // Mutual fund apps and platforms: SIP instalment and order confirmations.
    'paytmmoney.com', 'etmoney.com', 'mfcentral.com', 'bsestarmf.in',
    'mfuindia.com', 'scripbox.com', 'fisdom.com',
  ];

  /// Statement mails picked by subject, whoever sends them: a CAS forwarded by
  /// INDmoney or another app, NPS and EPF statements, and mutual fund purchase
  /// confirmations ("SIP instalment processed", "Units allotted").
  static const List<String> statementSubjects = [
    'Consolidated Account Statement',
    'NPS Transaction Statement',
    'PRAN',
    'EPF Passbook',
    'Member Passbook',
    'SIP installment',
    'SIP instalment',
    'units allotted',
    'allotment of units',
    'Statement of Transaction',
    'NPS contribution',
    'Holdings statement',
    'mutual fund statement',
    'Holdings report',
    'Balance statement',
    'Portfolio statement',
    'Holdings',
    'Portfolio report',
    'Fixed Deposit',
    'Term Deposit',
    'Recurring Deposit',
    'Deposit advice',
    'PPF statement',
    'Public Provident Fund',
    'portfolio summary',
  ];

  static final RegExp _statementSubject = rx(
    r'consolidated\s+account\s+statement|\bCAS\b|\bNPS\b.{0,40}statement|\bPRAN\b|\bEPF\b.{0,30}(?:passbook|statement)|member\s+passbook'
    r'|\bSIP\b.{0,60}\b(?:instal+ment|processed|successful|allot+ed)|\bunits?\s+(?:have\s+been\s+)?allot+ed|allotment\s+of\s+units'
    r'|statement\s+of\s+transactions?|\bNPS\b.{0,40}(?:contribution|holding|transaction)|\bholdings?\b|portfolio\s+(?:holdings|report)|(?:balance|portfolio|investment)\s+(?:statement|report)|mutual\s+fund\s+statement'
    r'|(?:fixed|term|recurring)\s+deposit|deposit\s+advice|\bPPF\b.{0,30}statement|public\s+provident\s+fund|portfolio\s+summary',
  );

  /// Whether an email [subject] marks a statement mail.
  static bool isStatementSubject(String? subject) =>
      subject != null && _statementSubject.hasMatch(subject);
}

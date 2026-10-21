import 'package:parser_core/src/bank/base_bank_parser.dart';
import 'package:parser_core/src/bank/loan_status.dart';
import 'package:parser_core/src/extract/channel_detector.dart';
import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/extract/reference_extractor.dart';
import 'package:parser_core/src/hash/transaction_hasher.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/parse_result.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/rules/rejection_rules.dart';
import 'package:parser_core/src/template/template.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/text/text_normalizer.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// A non-bank lender (NBFC or fintech): the name its loans are shown under, and
/// the senders it writes from.
class Lender {
  /// Creates a lender.
  const Lender(this.name, this.smsHeaders, this.emailDomains);

  /// Display name.
  final String name;

  /// SMS headers.
  final Set<String> smsHeaders;

  /// Email domains.
  final Set<String> emailDomains;
}

/// The lenders with their own parser. Their loans become loan accounts named
/// after them (FR-06-08).
abstract final class Lenders {
  /// The 17 lenders.
  static const List<Lender> all = [
    Lender(
      'Propelld',
      {'PROPLD', 'PRPLDF', 'PROPEL', 'PRPELD', 'PRPLDS'},
      {'propelld.com'},
    ),
    Lender(
      'Aditya Birla Capital',
      {'ABCLTD', 'ABCFIN', 'ABCAPL', 'ABCDAP', 'ADBIRL', 'ABFLTD', 'ABHFLT'},
      {'adityabirlacapital.com', 'abcd.adityabirlacapital.com'},
    ),
    Lender(
      'Bajaj Finance',
      {'BAJAJF', 'BAJFIN', 'BAJAJL', 'BFLEMI'},
      {'bajajfinserv.in', 'bajajfinance.in'},
    ),
    Lender('Tata Capital', {'TATACP', 'TATCAP', 'TCLOAN'}, {'tatacapital.com'}),
    Lender(
      'HDFC Credila',
      {'CREDLA', 'CREDIL', 'HCREDL'},
      {'credila.com', 'hdfccredila.com'},
    ),
    Lender('Avanse', {'AVANSE', 'AVNSFS'}, {'avanse.com'}),
    Lender('InCred', {'INCRED', 'INCRDF'}, {'incred.com'}),
    Lender(
      'SMFG India Credit',
      {'SMFGIN', 'SMFGIC', 'FULRTN', 'FULTON'},
      {'smfgindiacredit.com', 'fullertonindia.com'},
    ),
    Lender('Home Credit', {'HOMECR', 'HCINDA', 'HMCRDT'}, {'homecredit.co.in'}),
    Lender('KreditBee', {'KRDBEE', 'KBEEIN', 'KREDTB'}, {'kreditbee.in'}),
    Lender('Navi', {'NAVIFN', 'NAVILN', 'NAVIAP'}, {'navi.com'}),
    Lender(
      'Poonawalla Fincorp',
      {'POONAW', 'PFLTDL', 'PFLLON'},
      {'poonawallafincorp.com'},
    ),
    Lender('HDB Financial', {'HDBFSL', 'HDBFIN', 'HDBFSS'}, {'hdbfs.com'}),
    Lender('L&T Finance', {'LTFINC', 'LNTFIN', 'LTFSMS'}, {'ltfs.com'}),
    Lender('Hero FinCorp', {'HEROFC', 'HEROFN'}, {'herofincorp.com'}),
    Lender(
      'Cholamandalam Finance',
      {'CHOLAF', 'CHOLAL'},
      {'chola.murugappa.com'},
    ),
    Lender(
      'Mahindra Finance',
      {'MMFSLT', 'MAHFIN', 'MMFINL'},
      {'mahindrafinance.com'},
    ),
  ];

  static final Set<String> _names = {for (final l in all) l.name.toLowerCase()};

  /// True when [bankName] is one of these lenders: every account under it is a
  /// loan.
  static bool isLender(String bankName) =>
      _names.contains(bankName.toLowerCase());

  /// One parser per lender.
  static List<LenderParser> parsers([
    ParserConfig config = const ParserConfig(),
  ]) =>
      [for (final l in all) LenderParser(l, config)];
}

/// A lender's SMS and email. An EMI paid ("EMI of Rs.12,345 for your loan a/c
/// no. XXXX1234 has been received") is a debit filed under EMI & Loans on the
/// loan account; a disbursal, an outstanding figure or a reminder is a
/// [LoanStatus] (FR-06-15).
class LenderParser extends BaseBankParser {
  /// Creates the parser for [lender].
  LenderParser(this.lender, [super.config = const ParserConfig()]);

  /// The lender this parser reads for.
  final Lender lender;

  @override
  String get bankName => lender.name;

  @override
  Set<String> get smsHeaders => lender.smsHeaders;

  @override
  Set<String> get emailDomains => lender.emailDomains;

  @override
  ParseResult parseDetailed(
    String body,
    String sender,
    int timestamp,
    Source source,
  ) {
    final text = _textOf(body, source);
    if (text == null) return const NotATransaction('too short');
    final lower = text.toLowerCase();
    final reason = RejectionRules.reasonFor(text, lower);
    if (reason != null && !_soft.contains(reason)) return Rejected(reason);
    if (disbursed.hasMatch(text) || !paid.hasMatch(text)) {
      return const NotATransaction('not an EMI payment');
    }
    final money = emiAmount(text);
    if (money == null) return const NotATransaction('no amount');
    final last4 = loanLast4(text);
    final reference = ReferenceExtractor.normalize(
      ReferenceExtractor.extract(text, lower),
    );
    final date = civilDateOf(timestamp, config.utcOffset);
    return Parsed(
      ParsedTransaction(
        amountMinor: money.minor,
        currency: money.currency,
        type: TransactionType.debit,
        bankName: lender.name,
        accountLast4: last4,
        accountKind: AccountKind.account,
        merchant: lender.name,
        upiId: null,
        referenceNumber: reference,
        channel: ChannelDetector.detect(text, lower),
        balanceMinor: outstanding(text),
        availableLimitMinor: null,
        transactionTime: timestamp,
        hasExplicitTime: false,
        category: Category.emiLoan,
        source: source,
        sender: sender,
        messageTimestamp: timestamp,
        confidence: last4 != null ? 0.9 : 0.7,
        transactionHash: TransactionHasher.hash(
          money.minor,
          TransactionType.debit,
          last4,
          date,
          reference,
        ),
      ),
    );
  }

  /// The loan facts in a message that is not a payment; null when it names no
  /// loan or is an OTP, promotion or failure.
  LoanStatus? status(String body, int timestamp, Source source) {
    final text = _textOf(body, source);
    if (text == null) return null;
    final isDisbursed = disbursed.hasMatch(text);
    final reason = RejectionRules.reasonFor(text, text.toLowerCase());
    // "Congratulations! Your loan has been disbursed" reads as a promotion.
    if (reason != null &&
        !_soft.contains(reason) &&
        !(reason == 'promo' && isDisbursed)) {
      return null;
    }
    if (!isDisbursed && paid.hasMatch(text)) return null;
    final last4 = loanLast4(text);
    if (last4 == null) return null;
    final principal = isDisbursed ? principalOf(text) : null;
    return LoanStatus(
      lender.name,
      last4,
      principal,
      outstanding(text) ?? principal,
      timestamp,
    );
  }

  String? _textOf(String body, Source source) {
    final normalized = TextNormalizer.normalize(body);
    final text = source == Source.email
        ? TextNormalizer.trimEmail(normalized)
        : normalized;
    return text.length >= 20 ? text : null;
  }

  /// Rejection reasons that still leave loan facts to read: reminders, future
  /// debits, balance notes.
  static const _soft = {'future', 'reminder', 'balance'};

  static const _verb =
      '(?:received|paid|debited|deducted|collected|realised|realized|cleared)';
  static const String _amt = Template.amt;

  /// A completed repayment. "will be debited" and "not received" are not.
  static final RegExp paid = rx(
    r'\b(?:EMI|instal+ment|repayment|payment|INR\s*' +
        _amt +
        r')\b.{0,80}?(?<!\bbe )(?<!\bnot )\b' +
        _verb +
        r'\b'
            r'|\b(?:received|debited|deducted|collected)\b.{0,40}?\b(?:towards|for|against)\b.{0,20}?\b(?:EMI|loan|instal+ment|LAN)\b'
            r'|\breceived\s+(?:your\s+|the\s+)?(?:EMI|instal+ment|repayment|payment)\b'
            r'|\bthank(?:s|\s+you)\s+for\s+(?:your\s+|the\s+|making\s+(?:the\s+)?)?(?:EMI\s+)?(?:re)?payment\b',
  );

  /// A disbursal message.
  static final RegExp disbursed =
      rx(r'\b(?:disbursed|disbursal|disbursement)\b');

  static final RegExp _emiAmount = rx(
    r'\b(?:EMI|instal+ment|repayment|payment)\s+(?:amount\s+)?(?:of\s+|:\s*|-\s*)?INR\s*(' +
        _amt +
        ')',
  );
  static final RegExp _anyAmount = rx(r'\bINR\s*(' + _amt + ')');

  /// Words before an amount that make it something other than the EMI.
  static final RegExp _notEmi = rx(
    r'outstanding|principal|balance|\bbal\b|\bPOS\b|loan\s+(?:of|amount)|sanction|disburs|limit|overdue|charges?\b',
  );
  static final RegExp _outstanding = rx(
    r'\b(?:outstanding|balance\s+principal)\b(?!\s+(?:EMI|dues?|instal))(?:\s+(?:principal|loan|amount|balance))*.{0,40}?\bINR\s*(' +
        _amt +
        ')'
            r'|\bPOS\b\s*(?:is\s*|of\s*)?[:\-]?\s*INR\s*(' +
        _amt +
        ')',
  );
  static final RegExp _principal = rx(
    r'\b(?:loan|loan\s+amount|sanctioned\s+amount)\s+(?:of\s+)?INR\s*(' +
        _amt +
        r')|\bINR\s*(' +
        _amt +
        r')\b.{0,40}?\bdisburs|\bdisburs\w*\b.{0,30}?\bINR\s*(' +
        _amt +
        ')',
  );
  static const _number = r'([A-Z0-9*]*\d[A-Z0-9]{2,})';
  static final RegExp _loanNumber = rx(
    r'\b(?:loan\s+(?:a/c|ac|acct|account|id|no|number)|LAN|agreement|contract)\b\.?\s*'
            r'(?:(?:no|number|ending(?:\s+(?:with|in))?)\b\.?\s*)?[:\-#]?\s*' +
        _number +
        r'|\b(?:for|towards|on|against)\s+(?:your\s+)?loan\s+' +
        _number,
  );

  /// The EMI amount in [text].
  static Money? emiAmount(String text) {
    final e = findFrom(_emiAmount, text);
    if (e != null) {
      final m = Money.parse(grp(e, 1));
      if (m != null) return m;
    }
    for (final m in _anyAmount.allMatches(text)) {
      final from = m.start - 40 < 0 ? 0 : m.start - 40;
      if (_notEmi.hasMatch(text.substring(from, m.start))) continue;
      final money = Money.parse(grp(m, 1));
      if (money != null) return money;
    }
    return null;
  }

  /// The outstanding principal in [text], paise.
  static int? outstanding(String text) {
    final m = findFrom(_outstanding, text);
    if (m == null) return null;
    final g = firstGroup(m);
    return g == null ? null : Money.parse(g)?.minor;
  }

  /// The principal a disbursal message states, paise.
  static int? principalOf(String text) {
    final m = findFrom(_principal, text);
    if (m == null) return null;
    final g = firstGroup(m);
    return g == null ? null : Money.parse(g)?.minor;
  }

  /// The last 4 characters of the loan number: "XXXX1234" -> "1234",
  /// "PROP12345" -> "2345", "4XXXXX123" -> "123".
  static String? loanLast4(String text) {
    final m = findFrom(_loanNumber, text);
    if (m == null) return null;
    final g = firstGroup(m);
    if (g == null) return null;
    final number = lettersAndDigits(g.toUpperCase());
    final tail = takeLast(number, 4);
    if (!tail.contains('X')) return tail;
    final after = number.substring(number.lastIndexOf('X') + 1);
    return after.length >= 3 ? after : null;
  }
}

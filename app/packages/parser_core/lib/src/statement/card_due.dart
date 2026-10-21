import 'package:parser_core/src/statement/figures.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// What a card issuer's "statement generated / bill due" message (SMS or
/// email) says about a credit card, or, when only [paymentMinor] is set, a
/// payment it received. Not a transaction (FR-14-xx, FR-05-08).
class CardDue {
  /// Creates a card due.
  const CardDue({
    required this.bank,
    required this.last4,
    required this.totalDueMinor,
    required this.minDueMinor,
    required this.dueEpochDay,
    this.statementEpochDay,
    this.paymentMinor,
    this.at = 0,
  });

  /// The issuer, e.g. "HDFC Bank".
  final String bank;

  /// The card's last four digits; empty when the message names the card by its
  /// product name only.
  final String last4;

  /// Total amount due, paise.
  final int? totalDueMinor;

  /// Minimum amount due, paise.
  final int? minDueMinor;

  /// Due date as days since 1970-01-01 (`CivilDate.toEpochDay`).
  final int? dueEpochDay;

  /// Statement date as days since 1970-01-01.
  final int? statementEpochDay;

  /// A payment the issuer acknowledged ("payment of Rs 5,000 received"); then
  /// the due figures are null.
  final int? paymentMinor;

  /// When the message was sent, epoch ms.
  final int at;

  @override
  bool operator ==(Object other) =>
      other is CardDue &&
      other.bank == bank &&
      other.last4 == last4 &&
      other.totalDueMinor == totalDueMinor &&
      other.minDueMinor == minDueMinor &&
      other.dueEpochDay == dueEpochDay &&
      other.statementEpochDay == statementEpochDay &&
      other.paymentMinor == paymentMinor &&
      other.at == at;

  @override
  int get hashCode => Object.hash(
        bank,
        last4,
        totalDueMinor,
        minDueMinor,
        dueEpochDay,
        statementEpochDay,
        paymentMinor,
        at,
      );

  @override
  String toString() =>
      'CardDue($bank $last4 total=$totalDueMinor min=$minDueMinor '
      'due=$dueEpochDay paid=$paymentMinor)';
}

/// Reads card due and payment messages. See [CardDue].
abstract final class CardDueParser {
  static const _date = CardFigures.datePattern;
  static const _ccy = r'(?:\b(?:rs\.?|inr)|₹)';
  static const _amt = r'(\d[\d,]*(?:\.\d{1,2})?)';

  /// A number after a currency sign, or one with paise or thousands
  /// separators: never a bare "02" from a date.
  static const _numx =
      '(?:$_ccy\\s*(?=\\d)|(?=\\d[\\d,]*\\.\\d|\\d{1,3},\\d{2,3}))$_amt';

  static final RegExp _card = rx(r'\bcards?\b');
  static final RegExp _last4 = rx(
    r'(?:[x*]{2,}[\s-]?|ending\s+(?:with\s+|in\s+|no\.?\s*)?|\bno\.?\s*|\bnumber\s+)(\d{4})\b',
  );
  static final RegExp _min = rx(
    r'min(?:imum)?\.?(?:\s+(?:amt|amount|payment))?\.?\s+(?:due|payable)\b[^\d]{0,25}?' +
        _numx,
  );
  static final RegExp _total = rx(
    r'(?:total\s+(?:(?:amount|amt|payment)\.?\s+)?(?:due|payable|outstanding)|(?:total\s+)?amount\s+(?:due|payable)|'
            r'total\s+(?:amt|amount)(?!\s+(?:due|payable|outstanding))|total\s+dues?|new\s+balance|outstanding\s+(?:balance|amount)|bill\s+amount)\b[^\d]{0,25}?' +
        _numx,
  );
  static final RegExp _dueDate = rx(
    r'(?:due\s+(?:date|on|by)|pay(?:ment)?\s+(?:by|before)|payable\s+by|on\s+or\s+before)[\s:|–-]*(?:is\s+)?(' +
        _date +
        r')',
  );
  static final RegExp _statementDate = rx(
    r'(?:statement|bill)\s+(?:dated|date|generated\s+on|generated\s+for|of)[\s:|–-]*(?:is\s+)?(' +
        _date +
        r')',
  );
  static final RegExp _statementWord = rx(r'\b(?:statement|bill|due)\b');
  static final RegExp _failed = rx(
    r'\b(?:fail(?:ed|ure)?|declin\w+|unsuccessful|not\s+successful|reversed|reject\w*)\b',
  );
  static final List<RegExp> _payment = [
    rx(
      r'payment\s+of\s+' +
          _ccy +
          r'\s*' +
          _amt +
          r'[^.]{0,80}?\b(?:received|credited|posted|successful|made|paid)\b',
    ),
    rx(
      r'(?:received|credited|posted|thank\s+you\s+for)\s+(?:your\s+)?payment\s+of\s+' +
          _ccy +
          r'\s*' +
          _amt,
    ),
    rx(
      _ccy +
          r'\s*' +
          _amt +
          r'\s+(?:has\s+been\s+|was\s+)?(?:received|credited)\s+(?:towards|against|on|in)\b[^.]{0,40}card',
    ),
  ];
  static final List<(RegExp, String)> _banks = [
    (rx(r'\bHDFC\b'), 'HDFC Bank'),
    (rx(r'\bICICI\b'), 'ICICI Bank'),
    (rx(r'\bSBI\b|state\s+bank'), 'SBI'),
    (rx(r'\bAxis\b'), 'Axis Bank'),
    (rx(r'\bKotak\b'), 'Kotak Mahindra Bank'),
    (rx(r'\bIDFC\b'), 'IDFC FIRST Bank'),
    (rx(r'\bYes\s+Bank\b'), 'Yes Bank'),
    (rx(r'\bIndusInd\b'), 'IndusInd Bank'),
    (rx(r'\bAmerican\s+Express\b|\bAmex\b'), 'American Express'),
    (rx(r'\bHSBC\b'), 'HSBC'),
    (rx(r'\bRBL\b'), 'RBL Bank'),
    (rx(r'\bAU\s+(?:Small\s+Finance\s+)?Bank\b'), 'AU Small Finance Bank'),
    (rx(r'\bFederal\s+Bank\b'), 'Federal Bank'),
    (rx(r'\bStandard\s+Chartered\b'), 'Standard Chartered'),
  ];
  static final RegExp _spaces = RegExp('[\\s ]+');

  /// The issuer named in [text], or null.
  static String? bankIn(String text) {
    for (final (re, name) in _banks) {
      if (re.hasMatch(text)) return name;
    }
    return null;
  }

  /// The card figures in [body], or null when it is not about a credit card's
  /// bill or payment. [bank] is the issuer the sender belongs to; when null it
  /// is read from the text. [utcOffset] is the zone the dates are written in
  /// (IST by default).
  static CardDue? parse(
    String body,
    String? bank,
    int timestamp, {
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) {
    final text = body.replaceAll(_spaces, ' ').trim();
    if (!_card.hasMatch(text)) return null;
    // A bill that names the card only by its product name ("Regalia") has no
    // digits: the bank alone places it.
    final l4 = _last4.firstMatch(text);
    final last4 = l4 == null ? '' : grp(l4, 1);
    final issuer = bank ?? bankIn(text);
    if (issuer == null) return null;
    final received = civilDateOf(timestamp, utcOffset);

    final minMatch = _min.firstMatch(text);
    final min = minMatch == null ? null : CardFigures.minor(grp(minMatch, 1));
    // The minimum's own words must not be read as the total ("Minimum Amount
    // Due").
    final rest = minMatch == null
        ? text
        : text.replaceRange(
            minMatch.start,
            minMatch.end,
            ' ' * (minMatch.end - minMatch.start),
          );
    final totalMatch = _total.firstMatch(rest);
    final total =
        totalMatch == null ? null : CardFigures.minor(grp(totalMatch, 1));
    final sm = _statementDate.firstMatch(text);
    final stmt = sm == null
        ? null
        : CardFigures.parse(grp(sm, 1), ref: received, forward: false);
    final dm = _dueDate.firstMatch(text);
    final due = dm == null
        ? null
        : CardFigures.parse(grp(dm, 1), ref: stmt ?? received);

    if ((total != null || min != null) &&
        _statementWord.hasMatch(text) &&
        (total != null || due != null)) {
      return CardDue(
        bank: issuer,
        last4: last4,
        totalDueMinor: total,
        minDueMinor: min,
        dueEpochDay: due?.toEpochDay(),
        statementEpochDay: stmt?.toEpochDay(),
        at: timestamp,
      );
    }
    if (_failed.hasMatch(text) || last4.isEmpty) return null;
    for (final p in _payment) {
      final m = p.firstMatch(text);
      if (m == null) continue;
      final paid = CardFigures.minor(grp(m, 1));
      if (paid == null || paid <= 0) continue;
      return CardDue(
        bank: issuer,
        last4: last4,
        totalDueMinor: null,
        minDueMinor: null,
        dueEpochDay: null,
        paymentMinor: paid,
        at: timestamp,
      );
    }
    return null;
  }
}

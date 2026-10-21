import 'package:parser_core/src/bank/deposits.dart';
import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/model/holding.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/registry/sender_keys.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/text/text_normalizer.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// One NPS contribution credited to a PRAN, from a CRA's SMS or email
/// ("Contribution of Rs.5000 for PRAN XXXX1234 credited").
class NpsContribution {
  /// Creates a contribution.
  const NpsContribution(this.pranLast4, this.tier, this.amountMinor, this.date);

  /// Last four digits of the PRAN.
  final String pranLast4;

  /// 1 for Tier I, 2 for Tier II.
  final int tier;

  /// Amount, paise.
  final int amountMinor;

  /// Date credited.
  final CivilDate date;

  /// The NPS holding this contribution adds to: "NPS:1234" (Tier I) or
  /// "NPS:1234:T2".
  String get identifier => InvestmentParser.npsIdentifier(pranLast4, tier);

  /// Stable key, so the same contribution read twice (SMS and email, or a
  /// rescan) counts once.
  String get key => 'nps|$pranLast4|$tier|$date|$amountMinor';
}

/// Investment balances that arrive by SMS, such as EPFO's passbook balance and
/// NPS holding values. These are not bank transactions: an employer's PF
/// contribution never touches the user's account. They update a holding
/// instead. NPS contribution messages from the CRAs are read by
/// [npsContribution].
abstract final class InvestmentParser {
  static const _amt = r'([\d,]+(?:\.\d{1,2})?)';
  static final RegExp _epfBalance = rx(
    r'passbook\s+balance\s+against\s+(\S+?)\s+is\s+INR\s*' + _amt,
  );
  static final RegExp _epfContribution = rx(
    r'\bcontribution\s+of\s+INR\s*' +
        _amt +
        r'.{0,80}?\b(?:received|credited|deposited)\b',
  );
  static final RegExp _epfAlt =
      rx(r'\b(?:EPF|PF)\s+(?:a/c\s+)?balance\s+(?:is|of)\s+INR\s*' + _amt);
  static final RegExp _npsValue = rx(
    r'\bPRAN\b[^0-9]{0,20}[x*\d]*?(\d{4})\b.{0,120}?\b(?:holding|balance|value|corpus)\b.{0,60}?\bINR\s*' +
        _amt,
  );
  static final RegExp _npsValueFirst = rx(
    r'\b(?:holding|corpus|portfolio|account)\s+(?:value|balance)\b.{0,40}?\bINR\s*' +
        _amt +
        r'.{0,100}?\bPRAN\b[^0-9]{0,20}[x*\d]*?(\d{4})\b',
  );
  static final RegExp _pran =
      rx(r'\bPRAN\b(?:\s*(?:No\.?|Number))?[^0-9]{0,20}[x*\d]*?(\d{4})\b');
  static final RegExp _tierTwo = rx(r'\bTier\s*[-:]?\s*(?:II|2)\b');
  static final RegExp _npsContext =
      rx(r'\bNPS\b|\bPRAN\b|national\s+pension|\bCRA\b');
  static final RegExp _contribution = rx(
    r'\bcontribution|\bunits?\s+(?:have\s+been\s+|are\s+|were\s+)?(?:allotted|alloted|allocated|credited)\b|\bcredited\s+(?:to|in|into)\s+(?:your\s+)?(?:NPS|PRAN|Tier)|\bD-?Remit\b',
  );
  static final RegExp _contributionDone = rx(
    r'\bcredited\b|\ballot+ed\b|\ballocated\b|\breceived\b|\binvested\b|\bprocessed\b|\bsuccessful(?:ly)?\b|\bupdated\b',
  );
  static final RegExp _notDone = rx(
    r'\b(?:failed|failure|rejected|unsuccessful|pending|reminder|due\s+(?:on|date)|not\s+been|could\s+not|will\s+be|returned|reversed)\b',
  );
  static final RegExp _holdingWords = rx(
    r'\b(?:holding|corpus|portfolio)\s+(?:value|balance)\b|\btotal\s+value\b',
  );
  static final RegExp _amount = rx(r'\bINR\s*' + _amt);
  static final RegExp _dateOn = rx(
    r'\b(?:on|dated|date)\s*:?\s*(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{1,2}[\s-][A-Za-z]{3,9}[\s,-]+\d{2,4})',
  );

  /// CRA and regulator SMS headers without "NPS" in them: Protean (NSDL),
  /// KFintech and CAMS CRAs, PFRDA.
  static const _npsHeaders = {
    'NSDLPR', 'NSDLCR', 'NSDLNP', 'PROTEN', 'PRTEAN', 'PROTNC', 'KFINTN', //
    'KFNCRA', 'KFCRA', 'KCRA', 'KCRANP', 'CAMSNP', 'CAMSCR',
  };

  /// The identifier of an EPF balance whose member id the message did not give.
  static const epfDefault = 'EPF:default';

  /// SMS senders whose messages are investment updates. Looked at before any
  /// body is read.
  static bool accepts(String sender) {
    final h = SenderKeys.smsHeader(sender);
    return h.startsWith('EPFO') ||
        h == 'EPFIND' ||
        h == 'UMANGB' ||
        h.contains('NPS') ||
        h.contains('PRAN') ||
        h.startsWith('PFRDA') ||
        _npsHeaders.contains(h);
  }

  /// The EPF or NPS holding an investment SMS reports, or null.
  static HoldingSnapshot? parse(String body, String sender, int timestamp) {
    if (!accepts(sender)) return null;
    final text = TextNormalizer.normalize(body);
    final e = _epf(text, timestamp);
    if (e != null) return e;
    final n = npsValue(text, timestamp);
    if (n != null) return n;
    final m = _epfAlt.firstMatch(text);
    if (m != null) {
      final value = Money.parse(grp(m, 1))?.minor;
      if (value == null) return null;
      return HoldingSnapshot(
        kind: HoldingKind.epf,
        name: 'EPF',
        identifier: epfDefault,
        units: null,
        valueMinor: value,
        investedMinor: null,
        asOf: timestamp,
        contributionMinor: _epfContributionOf(text),
      );
    }
    return null;
  }

  /// An investment update in an email from EPFO, UMANG or an NPS CRA: the EPF
  /// passbook balance or an NPS holding value. Any sender; the caller decides
  /// which emails to read.
  static HoldingSnapshot? parseEmail(String body, int timestamp) {
    final text = TextNormalizer.normalize(body);
    return _epf(text, timestamp) ?? npsValue(text, timestamp);
  }

  static HoldingSnapshot? _epf(String text, int timestamp) {
    final m = _epfBalance.firstMatch(text);
    if (m == null) return null;
    final member = epfMemberKey(trimChars(grp(m, 1), '.,'));
    final value = Money.parse(grp(m, 2))?.minor;
    if (value == null) return null;
    return HoldingSnapshot(
      kind: HoldingKind.epf,
      name: 'EPF ••${takeLast(member, 4)}',
      identifier: 'EPF:$member',
      units: null,
      valueMinor: value,
      investedMinor: null,
      asOf: timestamp,
      contributionMinor: _epfContributionOf(text),
    );
  }

  static int? _epfContributionOf(String text) {
    final m = _epfContribution.firstMatch(text);
    if (m == null) return null;
    final v = Money.parse(grp(m, 1))?.minor;
    return v != null && v > 0 ? v : null;
  }

  /// "MH/BAN/0012345/000/0001234" and "MHBAN00123450000001234" are one member id.
  static String epfMemberKey(String raw) => lettersAndDigits(raw).toUpperCase();

  /// An NPS holding value in an SMS or email body ("holding value ... is Rs.
  /// 4,56,789.12" for a PRAN).
  static HoldingSnapshot? npsValue(String body, int timestamp) {
    final text = TextNormalizer.normalize(body);
    String last4;
    String amount;
    final a = _npsValue.firstMatch(text);
    if (a != null) {
      last4 = grp(a, 1);
      amount = grp(a, 2);
    } else {
      final b = _npsValueFirst.firstMatch(text);
      if (b == null) return null;
      last4 = grp(b, 2);
      amount = grp(b, 1);
    }
    final value = Money.parse(amount)?.minor;
    if (value == null) return null;
    final tier = _tierTwo.hasMatch(text) ? 2 : 1;
    return HoldingSnapshot(
      kind: HoldingKind.nps,
      name: npsName(last4, tier),
      identifier: npsIdentifier(last4, tier),
      units: null,
      valueMinor: value,
      investedMinor: null,
      asOf: timestamp,
    );
  }

  /// An NPS contribution credited to a PRAN: "Contribution of Rs.5000.00 for
  /// PRAN XXXXXXXX1234 has been credited", "Units for Rs 5000 contribution in
  /// PRAN 1100XXXX1234 Tier I have been allotted". Not for failed or pending
  /// ones, and not for holding-value messages.
  static NpsContribution? npsContribution(
    String body,
    int timestamp, {
    ParserConfig config = const ParserConfig(),
  }) {
    final text = TextNormalizer.normalize(body);
    if (!_npsContext.hasMatch(text) ||
        !_contribution.hasMatch(text) ||
        !_contributionDone.hasMatch(text)) {
      return null;
    }
    if (_notDone.hasMatch(text) || _holdingWords.hasMatch(text)) return null;
    final p = _pran.firstMatch(text);
    if (p == null) return null;
    final am = _amount.firstMatch(text);
    final amount = am == null ? null : Money.parse(grp(am, 1))?.minor;
    if (amount == null) return null;
    final received = civilDateOf(timestamp, config.utcOffset);
    final dm = _dateOn.firstMatch(text);
    var date = dm == null ? null : DepositParser.parseDate(grp(dm, 1));
    if (date != null &&
        (date.isAfter(received.plusDays(1)) ||
            date.isBefore(received.minusDays(45)))) {
      date = null;
    }
    return NpsContribution(
      grp(p, 1),
      _tierTwo.hasMatch(text) ? 2 : 1,
      amount,
      date ?? received,
    );
  }

  /// "NPS:1234" for Tier I, "NPS:1234:T2" for Tier II.
  static String npsIdentifier(String pranLast4, int tier) =>
      tier == 2 ? 'NPS:$pranLast4:T2' : 'NPS:$pranLast4';

  /// "NPS ••1234" or "NPS ••1234 Tier II".
  static String npsName(String pranLast4, int tier) =>
      tier == 2 ? 'NPS ••$pranLast4 Tier II' : 'NPS ••$pranLast4';
}

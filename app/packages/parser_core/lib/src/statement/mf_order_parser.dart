import 'package:parser_core/src/bank/deposits.dart';
import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/statement/figures.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// One mutual fund purchase (SIP instalment or lump sum) confirmed by an
/// investing app or the fund's registrar.
class MfOrder {
  /// Creates an order.
  const MfOrder({
    required this.platform,
    required this.schemeName,
    required this.folio,
    required this.amountMinor,
    required this.units,
    required this.nav,
    required this.date,
    required this.isSip,
  });

  /// The app or registrar that sent it: Groww, Zerodha Coin, CAMS...
  final String platform;

  /// Scheme name.
  final String schemeName;

  /// Folio number, if stated.
  final String? folio;

  /// Amount invested, paise.
  final int? amountMinor;

  /// Units allotted (a quantity, not money).
  final double? units;

  /// NAV per unit, rupees (a price, not an amount).
  final double? nav;

  /// Order date.
  final CivilDate date;

  /// A SIP instalment.
  final bool isSip;

  /// Holding identifier for a fund known only from these emails: "MF:" + the
  /// normalised scheme name.
  String get identifier => MfOrderParser.identifierFor(schemeName);
}

/// "SIP instalment processed", "Order successful", "Units allotted" emails from
/// Groww, Zerodha Coin, Kuvera, INDmoney, Paytm Money, ET Money, and
/// CAMS/KFintech transaction confirmations. Reads the scheme, amount, units,
/// NAV and date. Reminders, failed or cancelled orders, and redemptions are not
/// purchases and are ignored (FR-05-24).
class MfOrderParser {
  /// Creates a parser.
  const MfOrderParser([this.config = const ParserConfig()]);

  /// Zone and settings.
  final ParserConfig config;

  /// The order in a mail body, or null.
  MfOrder? parse(
    String text,
    String? subject,
    String sender,
    int receivedAt,
  ) {
    final body = _normalise([if (subject != null) subject, text].join('\n'));
    final flat = body.replaceAll('\n', ' ');
    if (!_aboutFunds.hasMatch(flat)) return null;
    if (!_purchase.hasMatch(flat)) return null;
    if (_notDone.hasMatch(flat) || _redemption.hasMatch(flat)) return null;
    if (!_done.hasMatch(flat)) return null;

    final scheme = _scheme(body);
    if (scheme == null) return null;
    final ul = _unitsLabel.firstMatch(flat);
    var units = ul == null ? null : _num(grp(ul, 1));
    if (units == null) {
      final ua = _unitsAfter.firstMatch(flat);
      units = ua == null ? null : _num(grp(ua, 1));
    }
    final nm = _nav.firstMatch(flat);
    var nav = nm == null ? null : _num(grp(nm, 1));
    if (nav != null && nav <= 0) nav = null;
    final am = _amountLabel.firstMatch(flat) ??
        _amountOf.firstMatch(flat) ??
        _amountAny.firstMatch(flat);
    int? amount;
    if (am != null) {
      final g = firstGroup(am);
      if (g != null) amount = Money.parse(g)?.minor;
    }
    amount ??= units != null && nav != null ? paise(units * nav) : null;
    if (amount == null && units == null) return null;
    final received = civilDateOf(receivedAt, config.utcOffset);
    final dl = _dateLabelled.firstMatch(flat) ?? _dateOn.firstMatch(flat);
    var date = dl == null ? null : DepositParser.parseDate(grp(dl, 1));
    if (date != null &&
        (date.isAfter(received.plusDays(1)) ||
            date.isBefore(received.minusDays(45)))) {
      date = null;
    }
    final fm = _folio.firstMatch(flat);
    final folio = fm == null ? null : trimChars(grp(fm, 1), '/.');
    return MfOrder(
      platform: platformOf(sender, flat),
      schemeName: scheme,
      folio: folio,
      amountMinor: amount,
      units: units != null && units > 0 ? units : null,
      nav: nav,
      date: date ?? received,
      isSip: _sip.hasMatch(flat),
    );
  }

  String? _scheme(String body) {
    for (final line in body.split(RegExp(r'\r\n|\n|\r'))) {
      final m = _schemeLabel.firstMatch(line);
      if (m != null) {
        final c = _clean(grp(m, 1));
        if (c != null) return c;
      }
    }
    final flat = body.replaceAll('\n', ' ');
    for (final r in _schemeSentences) {
      for (final m in r.allMatches(flat)) {
        final c = _clean(grp(m, 1));
        if (c != null) return c;
      }
    }
    return null;
  }

  String? _clean(String raw) {
    final s = trimChars(
      raw.replaceAll(_trailingJunk, '').replaceAll(_ws, ' ').trim(),
      '-,.:| "\'',
    ).replaceFirst(_leadingJunk, '');
    if (s.length < 6 || s.length > 120) return null;
    if (!_schemeWord.hasMatch(s)) return null;
    return s;
  }

  /// Scheme names to one key: lower case, no punctuation, without "direct",
  /// "plan", "growth", "option", "fund".
  static String normaliseScheme(String name) => name
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp('[^a-z0-9 ]'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty && !_stopWords.contains(w))
      .join(' ');

  /// "MF:" + the normalised scheme name.
  static String identifierFor(String schemeName) =>
      'MF:${normaliseScheme(schemeName)}';

  static const _stopWords = {
    'direct', 'dir', 'plan', 'growth', 'gr', 'g', 'option', 'opt', 'fund', //
    'the', 'scheme', 'dp', 'gw', 'mf', 'mutual',
  };

  static double? _num(String s) => parseDouble(s.replaceAll(',', ''));

  static String _normalise(String s) => s
      .replaceAll(' ', ' ')
      .replaceAll(
        RegExp(r'(?:₹|\bINR\b\.?|\bRs\b\.?)\s*', caseSensitive: false),
        'Rs. ',
      )
      .split(RegExp(r'\r\n|\n|\r'))
      .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .join('\n');

  static final RegExp _ws = RegExp(r'\s+');

  static const _amt = r'([\d,]+(?:\.\d{1,2})?)(?![\d.])';
  static const _dec = r'([\d,]*\d\.\d+|\d[\d,]*)';
  static const _d =
      r'(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}-\d{2}-\d{2}|\d{1,2}(?:st|nd|rd|th)?[\s-][A-Za-z]{3,9}[\s,-]+\d{2,4}|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})';

  static final RegExp _aboutFunds =
      rx(r'\bmutual\s+funds?\b|\bfund\b|\bSIP\b|\bNAV\b|\bfolio\b|\bunits?\b');
  static final RegExp _purchase = rx(
    r'\bSIP\b|systematic\s+investment|\bpurchase\b|\binvest(?:ment|ed)?\b|\border\b|\bunits?\s+(?:have\s+been\s+|are\s+|were\s+)?(?:allotted|alloted|allocated|credited)\b|\ballotment\b|\blumpsum\b',
  );
  static final RegExp _done = rx(
    r'\bsuccess(?:ful(?:ly)?)?\b|\bprocessed\b|\ballot+ed\b|\ballotment\b|\ballocated\b|\bconfirm(?:ed|ation)\b|\bexecuted\b|\bcompleted\b|\bplaced\b|\bcredited\b|\binvested\b',
  );
  static final RegExp _notDone = rx(
    r"\b(?:failed|failure|unsuccessful|rejected|cancel+ed|cancel+ation|could\s+not|couldn't|insufficient|bounced?|skipped|paused|reminder|upcoming|due\s+(?:on|tomorrow|today)|will\s+be\s+(?:debited|deducted)|scheduled\s+for|mandate\s+(?:registration|setup|approved))\b",
  );
  static final RegExp _redemption = rx(
    r'\bredeem(?:ed)?\b|\bredemption\b|\bwithdrawal\b|\bswitch[\s-]?out\b|\bSWP\b|\bsell\s+order\b',
  );
  static final RegExp _sip = rx(r'\bSIP\b|systematic\s+investment');

  static final RegExp _schemeLabel = rx(
    r'(?:(?:^|[|,;]\s*)(?:scheme|fund)(?:\s+name)?\s*[:\-]|\b(?:scheme|fund)\s+name\s*[:\-]?)\s*(.+?)(?=\s+(?:folio|amount|units?|nav|transaction|txn|date|order|plan\s+type|option\s*:)\b|\s*[|;]|$)',
  );
  static final List<RegExp> _schemeSentences = [
    // "SIP instalment for Parag Parikh Flexi Cap Fund Direct Growth has been
    // processed"
    rx(
      r'(?:\bSIP\b(?:\s+instal+ments?)?|\binvestment|\border|\bpurchase|\binvested)(?:\s+of\s+Rs\.\s*[\d,]+(?:\.\d+)?)?\s+(?:for|in|into)\s+(?:the\s+)?(.+?)(?=\s+(?:has|have|is|was|were|under|with|on|at|via|through|of\s+Rs|for\s+Rs|folio)\b|\s*[(,;!]|\.\s|\.$|$)',
    ),
    // "Units allotted in Axis Bluechip Fund - Direct Growth"
    rx(
      r'\bunits?\s+(?:of|in)\s+(.+?)(?=\s+(?:has|have|is|was|were|under|with|on|at|folio)\b|\s*[(,;!]|\.\s|\.$|$)',
    ),
  ];
  static final RegExp _schemeWord =
      rx(r'\b(?:fund|funds|plan|growth|ETF|FoF|IDCW|index|scheme|bees)\b');
  static final RegExp _trailingJunk = rx(r'\s*(?:-\s*)?(?:folio.*|\(.*)$');
  static final RegExp _leadingJunk = rx(r'^(?:your|the|a|an)\s+');

  static final RegExp _unitsLabel = rx(
    r'\bunits?(?:\s+(?:allotted|alloted|allocated|credited|purchased|bought))?\s*(?:\(\s*no\.?\s*\))?\s*[:\-]?\s*' +
        _dec,
  );
  static final RegExp _unitsAfter = rx(_dec + r'\s+units?\b');
  static final RegExp _nav = rx(
    r'\bNAV\b(?:\s*\(\s*Rs\.\s*\))?(?:\s+(?:per\s+unit|of|at|is|was|applied|allotted))*\s*[:\-]?\s*(?:Rs\.\s*)?([\d,]*\d\.\d+|\d[\d,]*)',
  );
  static final RegExp _amountLabel = rx(
    r'\b(?:investment|sip|order|purchase|instal+ment|transaction|gross|net)?\s*amount(?:\s+(?:invested|paid|debited))?\s*(?:\(\s*Rs\.\s*\))?\s*[:\-]?\s*(?:Rs\.\s*)' +
        _amt +
        r'|\bamount(?:\s+(?:invested|paid))?\s*(?:\(\s*Rs\.\s*\))?\s*[:\-]\s*(?:Rs\.\s*)?' +
        _amt,
  );
  static final RegExp _amountOf = rx(r'\b(?:of|for|worth)\s+Rs\.\s*' + _amt);
  static final RegExp _amountAny =
      rx(r'Rs\.\s*' + _amt + r'(?!\s*(?:per\s+unit|/unit))');
  static final RegExp _folio =
      rx(r'\bfolio(?:\s+(?:no\.?|number|#))?\s*[:\-]?\s*([\d/]{5,})');
  static final RegExp _dateLabelled = rx(
    r'\b(?:allotment|nav|transaction|trade|order|txn|investment|purchase|processing|instal+ment|sip)\s+date\s*[:\-]?\s*' +
        _d,
  );
  static final RegExp _dateOn = rx(r'\b(?:on|dated)\s+' + _d);

  static const _platforms = <(String, String)>[
    ('groww', 'Groww'), ('zerodha', 'Zerodha Coin'), ('kuvera', 'Kuvera'), //
    ('indmoney', 'INDmoney'), ('paytmmoney', 'Paytm Money'),
    ('paytm money', 'Paytm Money'), ('etmoney', 'ET Money'),
    ('et money', 'ET Money'), ('camsonline', 'CAMS'),
    ('kfintech', 'KFintech'), ('karvy', 'KFintech'), ('upstox', 'Upstox'),
    ('angelone', 'Angel One'), ('dhan', 'Dhan'), ('mfcentral', 'MF Central'),
    ('bsestarmf', 'BSE StAR MF'), ('mfuindia', 'MF Utility'),
    ('scripbox', 'Scripbox'), ('fisdom', 'Fisdom'),
  ];

  /// The platform a mail came from: by sender, then by text, then the sender's
  /// display name.
  static String platformOf(String sender, [String text = '']) {
    final s = sender.toLowerCase();
    for (final (k, v) in _platforms) {
      if (s.contains(k)) return v;
    }
    final t = text.toLowerCase();
    for (final (k, v) in _platforms) {
      if (t.contains(k)) return v;
    }
    final lt = sender.indexOf('<');
    final name =
        trimChars((lt < 0 ? sender : sender.substring(0, lt)).trim(), '"');
    return name.isEmpty ? 'Mutual fund' : name;
  }

  /// Domains these confirmations come from, for the email sender whitelist.
  static const senderDomains = [
    'groww.in', 'zerodha.com', 'zerodha.net', 'kuvera.in', 'indmoney.com', //
    'paytmmoney.com', 'etmoney.com', 'camsonline.com', 'kfintech.com',
    'mfcentral.com', 'bsestarmf.in', 'mfuindia.com', 'scripbox.com',
    'fisdom.com',
  ];
}

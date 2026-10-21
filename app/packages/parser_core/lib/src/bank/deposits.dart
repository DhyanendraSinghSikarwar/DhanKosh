import 'package:parser_core/src/bank/loan_status.dart';
import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/text/text_normalizer.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// FD, RD and PPF messages from banks and India Post: booking and renewal
/// advices ("FD No. XXXX5678 for INR 1,00,000 booked at 7.10% p.a., maturity
/// 12-Mar-2027, maturity amount INR 1,07,281"), maturity and closure notes, RD
/// instalments and PPF deposits or interest with the running balance. Needs the
/// deposit's own number; promotions ("Book an FD at 7.5%") never name one
/// (FR-06-15).
abstract final class DepositParser {
  static const _amt = r'(\d[\d,]*(?:\.\d{1,2})?)';
  static const _num =
      r'(?:a/c|ac|acct|account|receipt|rcpt)?\.?\s*(?:no\.?|number|ending(?:\s+(?:with|in))?)?\s*[:\-#]?\s*([Xx*\d][Xx*\d-]*\d)';

  static final List<(DepositKind, RegExp)> _numbered = [
    (DepositKind.ppf, rx(r'(?:\bPPF\b|public\s+provident\s+fund)\s*' + _num)),
    (DepositKind.rd, rx(r'(?:\bRD\b|recurring\s+deposit)\s*' + _num)),
    (
      DepositKind.fd,
      rx(
        r'(?:\bFDR?\b|fixed\s+deposit|term\s+deposit|\bTD\b|\bSDR\b|\bMIS\b)\s*' +
            _num,
      ),
    ),
  ];
  static final RegExp _quick = rx(
    r'\bPPF\b|provident\s+fund|\bRD\b|recurring\s+deposit|\bFDR?\b|fixed\s+deposit|term\s+deposit|\bTD\b|\bSDR\b|\bMIS\b',
  );
  static final RegExp _context = rx(
    r'\b(?:booked|opened|created|placed|renewed|renewal|matur\w*|bal(?:ance)?|interest|instal+ment|deposited|credited|received|closed|closure|liquidated)\b',
  );
  static final RegExp _notStatus = rx(
    r'\b(?:OTP|one\s+time\s+password|failed|unsuccessful|declined|offer|book\s+now|apply\s+now|earn\s+up\s+to|loan\s+against|overdraft)\b',
  );

  static final RegExp _maturityAmount = rx(
    r'\bmatur\w*\s+(?:amount|value|proceeds)\s*(?:\(\s*INR\s*\))?\s*(?:of|is|:|-|will\s+be|would\s+be)?\s*:?\s*(?:INR\s*)?' +
        _amt +
        r'|\bINR\s*' +
        _amt +
        r'\s+(?:on|at)\s+maturity',
  );
  static final RegExp _balance = rx(
    r'\b(?:total\s+|available\s+|avl\.?\s+|clear\s+|current\s+|closing\s+|updated\s+)?bal(?:ance)?\.?\s*(?:is|of|:|-|now)?\s*:?\s*INR\s*' +
        _amt,
  );
  static final RegExp _anyAmount = rx(r'\bINR\s*' + _amt);

  /// Words before an amount that make it something other than the amount
  /// deposited.
  static final RegExp _notPrincipal =
      rx(r'matur\w*|interest|\bbal(?:ance)?\b|proceeds|limit|penalty|charges?');
  static const _date =
      r'(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}-\d{2}-\d{2}|\d{1,2}(?:st|nd|rd|th)?[\s-][A-Za-z]{3,9}[\s,-]+\d{2,4}|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})';
  static final RegExp _maturityDate = rx(
    r'\bmatur(?:ity|es|ing|ed|e)?\b(?:\s+date)?\s*(?:is|on|:|-|will\s+be|due)?\s*(?:on\s+)?:?\s*' +
        _date +
        r'|\bdue\s+(?:for\s+maturity\s+)?on\s+' +
        _date +
        r'|\bmaturity\s+date\s*[:\-]?\s*' +
        _date,
  );
  static final RegExp _rate = rx(
    r'(?:@|\bat\b|\brate\b(?:\s+of\s+interest)?|\bROI\b|\binterest\s+rate\b)\s*(?:of|is|:)?\s*(\d{1,2}(?:\.\d{1,2})?)\s*%',
  );
  static final RegExp _notRenewed =
      rx(r'\bnot\s+(?:be\s+)?(?:auto[\s-]?)?renew\w*');
  static final RegExp _renew =
      rx(r'\bauto[\s-]?renew\w*|\brenew(?:ed|al|s)?\b');
  static final RegExp _payout = rx(
    r'\bauto[\s-]?clos\w*|\bpay\s*-?\s*out\b|\bpaid\s+out\b|\bclosure\s+on\s+maturity|\bcredited\s+to\s+(?:your\s+)?(?:savings\s+|linked\s+|SB\s+)?(?:a/c|account)\b.{0,30}\bon\s+maturity|\bon\s+maturity\b.{0,60}\bwill\s+be\s+credited'
    r'|\bmaturity\s+instructions?\s*[:\-]?\s*(?:credit|pay|close|closure|transfer)',
  );
  static final RegExp _interestOut = rx(
    r'\binterest\b.{0,40}\b(?:paid|credited|payout)\b|\bprincipal\s+(?:only\s+)?renew',
  );
  static final RegExp _closed = rx(
    r'\b(?:has|have|was|is)\s+(?:been\s+)?(?:matured|closed|prematurely\s+closed|liquidated|redeemed)\b|\bmatured\b.{0,80}\b(?:credited|paid|proceeds)\b'
    r'|\bproceeds\b(?:(?!\bwill\b).){0,60}\bcredited\b|\bpremature(?:ly)?\s+(?:closed|closure|withdrawal|withdrawn)\b',
  );
  static final RegExp _ppfClosed =
      rx(r'\b(?:account|a/c)\s+(?:has\s+been\s+|is\s+)?closed\b');
  static final RegExp _indiaPost = rx('^(?:DOP|IPPB|INDPST|INDPOS|POSTAL)');

  /// True when [text] might be about a deposit at all; a cheap first look.
  static bool mentionsDeposit(String text) => _quick.hasMatch(text);

  /// The deposit status in [body] from [bank], or null when it names no
  /// deposit number, or is an OTP, offer or failure. [timestamp] is when the
  /// bank sent it.
  static LoanStatus? status(String body, String bank, int timestamp) {
    final text = TextNormalizer.normalize(body);
    if (!_quick.hasMatch(text) ||
        _notStatus.hasMatch(text) ||
        !_context.hasMatch(text)) {
      return null;
    }
    final n = numbered(text);
    if (n == null) return null;
    final (kind, last4) = n;
    final deposit = info(text, kind);
    final principalMinor = _principal(text);
    final bal = findFrom(_balance, text);
    final balance = bal == null ? null : _firstAmount(bal);
    // An FD's balance is its principal; an RD's or PPF's instalment is not its
    // balance.
    final int? outstanding;
    if (deposit.closed) {
      outstanding = null;
    } else if (balance != null) {
      outstanding = balance;
    } else if (kind == DepositKind.fd) {
      outstanding = principalMinor;
    } else {
      outstanding = null;
    }
    return LoanStatus(
      _nameOf(bank),
      last4,
      principalMinor,
      outstanding,
      timestamp,
      deposit: deposit,
    );
  }

  /// True when [text] is about the deposit account itself (a booking advice, an
  /// RD instalment or PPF deposit received on [accountLast4]), so it is not a
  /// transaction on a bank account: the money already left the savings account
  /// in its own message. A debit from a savings account "towards RD XX9012"
  /// names a different account and stays.
  static bool aboutDepositOnly(String text, String? accountLast4) {
    if (!_quick.hasMatch(text)) return false;
    final n = numbered(TextNormalizer.normalize(text));
    if (n == null) return false;
    return accountLast4 == null || accountLast4 == n.$2;
  }

  /// The terms in a deposit advice or statement; the kind is whatever the
  /// caller knows it to be.
  static DepositInfo info(String text, DepositKind kind) {
    final md = findFrom(_maturityDate, text);
    final mdText = md == null ? null : firstGroup(md);
    final maturity = mdText == null ? null : parseDate(mdText);
    final ma = findFrom(_maturityAmount, text);
    final maturityAmount = ma == null ? null : _firstAmount(ma);
    final rateM = findFrom(_rate, text);
    final rate = rateM == null ? null : _rateBps(grp(rateM, 1));
    final notRenewed = _notRenewed.hasMatch(text);
    final renewed = !notRenewed && _renew.hasMatch(text);
    final DepositAction? action;
    if (renewed && _interestOut.hasMatch(text)) {
      action = DepositAction.renewPrincipal;
    } else if (renewed) {
      action = DepositAction.renewAll;
    } else if (notRenewed || _payout.hasMatch(text)) {
      action = DepositAction.payout;
    } else {
      action = null;
    }
    final closed =
        (!renewed && kind != DepositKind.ppf && _closed.hasMatch(text)) ||
            (kind == DepositKind.ppf && _ppfClosed.hasMatch(text));
    return DepositInfo(
      kind,
      maturity: maturity,
      maturityAmountMinor: maturityAmount,
      rateBps: rate,
      action: action,
      closed: closed,
    );
  }

  /// "7.10" -> 710 when within 0.5% to 20%; exact decimal arithmetic.
  static int? _rateBps(String s) {
    final dot = s.indexOf('.');
    final whole = int.parse(dot < 0 ? s : s.substring(0, dot));
    final frac = dot < 0 ? '00' : s.substring(dot + 1).padRight(2, '0');
    final bps = whole * 100 + int.parse(frac);
    return bps >= 50 && bps <= 2000 ? bps : null;
  }

  /// The first deposit number in [text] and its kind; the last four digits
  /// name the account.
  static (DepositKind, String)? numbered(String text) {
    (DepositKind, RegExpMatch, String)? best;
    for (final (kind, re) in _numbered) {
      final m = findFrom(re, text);
      if (m == null) continue;
      final number = grp(m, 1);
      if (number.split('').where(isDigit).length < 3) continue;
      if (best == null || m.start < best.$2.start) best = (kind, m, number);
    }
    if (best == null) return null;
    final digits = lettersAndDigits(best.$3);
    final tail = takeLast(digits, 4);
    if (tail.contains('X') || tail.contains('x')) {
      final afterX = digits.substring(digits.lastIndexOf('X') + 1);
      final afterx = afterX.substring(afterX.lastIndexOf('x') + 1);
      if (afterx.length < 3) return null;
      return (best.$1, afterx);
    }
    return (best.$1, tail);
  }

  /// "DOPBNK" (the generic parser's name for India Post's sender) reads as
  /// India Post.
  static String _nameOf(String bank) =>
      _indiaPost.hasMatch(bank.toUpperCase()) ? 'India Post' : bank;

  /// The first amount not labelled as the maturity value, interest or a
  /// balance.
  static int? _principal(String text) {
    for (final m in _anyAmount.allMatches(text)) {
      final from = m.start - 30 < 0 ? 0 : m.start - 30;
      if (!_notPrincipal.hasMatch(text.substring(from, m.start))) {
        return _firstAmount(m);
      }
    }
    return null;
  }

  static int? _firstAmount(Match m) {
    final g = firstGroup(m);
    return g == null ? null : Money.parse(g)?.minor;
  }

  static const _monthAbbr = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct',
    'nov', 'dec', //
  ];
  static const _monthFull = [
    'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august',
    'september', 'october', 'november', 'december', //
  ];
  static final _numericDate = RegExp(r'^(\d{1,2})([/.-])(\d{1,2})\2(\d+)$');
  static final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final _dayMonthYear = RegExp(r'^(\d{1,2})([ -])([A-Za-z]+)\2(\d+)$');
  static final _monthDayYear = RegExp(r'^([A-Za-z]+) (\d{1,2}) (\d{4})$');
  static final _ordinal = RegExp(r'(\d)(?:st|nd|rd|th)\b');

  /// Parses the date spellings of deposit advices (`d/M/uuuu`, `d-MMM-uu`,
  /// `MMMM d uuuu`, ...); null when none fits. A day past the end of the month
  /// is clamped to it, as Java's smart resolver does.
  static CivilDate? parseDate(String s) {
    final t = s
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(',', '')
        .replaceAllMapped(_ordinal, (m) => grp(m, 1));
    int? year(String y) {
      if (y.length == 2) return 2000 + int.parse(y);
      return y.length >= 4 ? int.parse(y) : null;
    }

    int? month(String name) {
      final n = name.toLowerCase();
      final a = _monthAbbr.indexOf(n);
      if (a >= 0) return a + 1;
      final f = _monthFull.indexOf(n);
      return f >= 0 ? f + 1 : null;
    }

    CivilDate? make(int? y, int? m, int d) {
      if (y == null || m == null || m < 1 || m > 12 || d < 1 || d > 31) {
        return null;
      }
      final last = DateTime.utc(y, m + 1, 0).day;
      return CivilDate(y, m, d > last ? last : d);
    }

    final numeric = _numericDate.firstMatch(t);
    if (numeric != null) {
      final y = grp(numeric, 4);
      if (y.length == 3 || y.length > 4) return null;
      return make(
        year(y),
        int.parse(grp(numeric, 3)),
        int.parse(grp(numeric, 1)),
      );
    }
    final iso = _isoDate.firstMatch(t);
    if (iso != null) {
      return make(
        int.parse(grp(iso, 1)),
        int.parse(grp(iso, 2)),
        int.parse(grp(iso, 3)),
      );
    }
    final dmy = _dayMonthYear.firstMatch(t);
    if (dmy != null) {
      final y = grp(dmy, 4);
      if (y.length == 3 || y.length > 4) return null;
      return make(year(y), month(grp(dmy, 3)), int.parse(grp(dmy, 1)));
    }
    final mdy = _monthDayYear.firstMatch(t);
    if (mdy != null) {
      return make(
        int.parse(grp(mdy, 3)),
        month(grp(mdy, 1)),
        int.parse(grp(mdy, 2)),
      );
    }
    return null;
  }
}

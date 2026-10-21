import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// Kotlin `Math.round(double)`: halves round up.
int roundHalfUp(double x) => (x + 0.5).floor();

/// Rupees (a figure read from a statement) to paise. Figures have at most two
/// decimals, so the product is exact before rounding.
int paise(double rupees) => roundHalfUp(rupees * 100);

/// A number read from text, or null (`toDoubleOrNull` without hex or
/// exponent forms).
double? parseDouble(String s) {
  final t = s.trim();
  if (t.isEmpty || !_plain.hasMatch(t)) return null;
  return double.tryParse(t);
}

final RegExp _plain = RegExp(r'^[+-]?(?:\d+\.?\d*|\.\d+)$');

/// The local date of [epochMs].
CivilDate localDate(int epochMs, Duration offset) =>
    civilDateOf(epochMs, offset);

/// Noon of [date] in the zone at [offset], epoch ms (statement rows carry no
/// time of day).
int noonOf(CivilDate date, Duration offset) =>
    epochOf(date, const CivilTime(12, 0), offset);

final RegExp _ws = RegExp(r'\s+');

/// [s] split on runs of white space, empty pieces dropped.
List<String> words(String s) => s.split(_ws).where((w) => w.isNotEmpty).toList();

/// A date and amount spelling card statements and messages use.
const String _mon =
    r'(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';

/// Dates and amounts as card statements and messages print them.
abstract final class CardFigures {
  /// 12/10/2026, 12-10-26, 2026-10-12, 12-Oct-2026, 12 October 2026, 12 Oct,
  /// October 12, 2026.
  static const String datePattern =
      r'(?<!\d)(?:\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}-\d{2}-\d{2}|'
      r'\d{1,2}(?:st|nd|rd|th)?[\s-]+' +
          _mon +
          r'\b\.?(?:[\s,-]+\d{4}\b|-\d{2}\b)?|' +
          _mon +
          r'\b\.?\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4})';

  /// [datePattern], compiled.
  static final RegExp date = rx(datePattern);

  /// An amount with optional currency and trailing Cr/Dr: group 1 after a
  /// currency sign, group 2 with commas or paise, group 3 Cr/Dr.
  static final RegExp amount = rx(
    r'(?:(?:\b(?:rs\.?|inr)|₹|`)\s*(\d+(?:,\d{2,3})*(?:\.\d{1,2})?)|(?<![\d,.])(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+\.\d{1,2})(?![\d]|\.\d))'
    r'(?:\s*\b(cr|dr)\b)?',
  );

  /// Every amount in [s] with its Cr flag.
  static List<CardAmount> amounts(String s) {
    final out = <CardAmount>[];
    for (final m in amount.allMatches(s)) {
      final g1 = grp(m, 1);
      final n = g1.isEmpty ? grp(m, 2) : g1;
      final v = minor(n);
      if (v != null) {
        out.add(CardAmount(v, grp(m, 3).toLowerCase() == 'cr'));
      }
    }
    return out;
  }

  /// "1,234.5" -> 123450; null outside 0..Rs 10,000 crore.
  static int? minor(String number) =>
      Money.parseSigned(trimChars(number.replaceAll(',', ''), '.'));

  static final RegExp _numeric = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})$');
  static final RegExp _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _dayFirst =
      rx(r'^(\d{1,2})(?:st|nd|rd|th)?[\s-]+([a-z]+)\.?(?:[\s,-]+(\d{2,4}))?$');
  static final RegExp _monthFirst =
      rx(r'^([a-z]+)\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})$');
  static const _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  static int? _month(String name) {
    final n = name.length >= 3 ? name.substring(0, 3) : name;
    final i = _months.indexOf(n.toLowerCase());
    return i < 0 ? null : i + 1;
  }

  static int _year(String y) {
    final v = int.parse(y);
    return y.length <= 2 ? 2000 + v : v;
  }

  /// Reads a date in any of the forms above. A date without a year takes the
  /// year of [ref]: a future date ([forward], a due date) is moved to next
  /// year when it would fall well before [ref], a past date (a statement date)
  /// to last year when it would fall well after. [ref] defaults to today.
  static CivilDate? parse(String s, {CivilDate? ref, bool forward = true}) {
    final t = s.trim().replaceAll(_ws, ' ');
    final n = _numeric.firstMatch(t);
    if (n != null) {
      return CivilDate.tryCreate(
        _year(grp(n, 3)),
        int.parse(grp(n, 2)),
        int.parse(grp(n, 1)),
      );
    }
    final i = _iso.firstMatch(t);
    if (i != null) {
      return CivilDate.tryCreate(
        int.parse(grp(i, 1)),
        int.parse(grp(i, 2)),
        int.parse(grp(i, 3)),
      );
    }
    final mf = _monthFirst.firstMatch(t);
    if (mf != null) {
      final mo = _month(grp(mf, 1));
      if (mo == null) return null;
      return CivilDate.tryCreate(
        int.parse(grp(mf, 3)),
        mo,
        int.parse(grp(mf, 2)),
      );
    }
    final m = _dayFirst.firstMatch(t);
    if (m == null) return null;
    final mo = _month(grp(m, 2));
    if (mo == null) return null;
    final y = grp(m, 3);
    final day = int.parse(grp(m, 1));
    if (y.isNotEmpty) return CivilDate.tryCreate(_year(y), mo, day);
    final base = ref ?? _today();
    final last = DateTime.utc(base.year, mo + 1, 0).day;
    final d = CivilDate.tryCreate(base.year, mo, day > last ? last : day);
    if (d == null) return null;
    if (forward && d.isBefore(base.minusDays(30))) return d.plusYears(1);
    if (!forward && d.isAfter(base.plusDays(30))) return d.minusYears(1);
    return d;
  }

  static CivilDate _today() {
    final n = DateTime.now();
    return CivilDate(n.year, n.month, n.day);
  }
}

/// An amount and whether it is a credit (Cr).
class CardAmount {
  /// Creates an amount.
  const CardAmount(this.minor, this.credit);

  /// Paise.
  final int minor;

  /// Printed with Cr.
  final bool credit;
}

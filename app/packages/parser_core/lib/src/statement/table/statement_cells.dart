import 'package:parser_core/src/util/civil.dart';

/// The direction a cell's own text gives an amount.
enum AmountSign { debit, credit, unknown }

/// An amount read from one spreadsheet cell: always positive paise plus the
/// sign the text carried ([AmountSign.unknown] when it carried none).
class AmountCell {
  /// Creates an amount cell.
  const AmountCell(this.minor, this.sign);

  /// Absolute value in paise.
  final int minor;

  /// Debit for "Dr", brackets and a minus sign; credit for "Cr" and a plus.
  final AmountSign sign;

  @override
  bool operator ==(Object other) =>
      other is AmountCell && other.minor == minor && other.sign == sign;

  @override
  int get hashCode => Object.hash(minor, sign);

  @override
  String toString() => 'AmountCell($minor, ${sign.name})';
}

/// Reads statement amounts as banks write them (FR-05-28).
abstract final class StatementAmounts {
  static final RegExp _suffix =
      RegExp(r'\b(dr|cr)\b\.?\s*$', caseSensitive: false);
  static final RegExp _prefix =
      RegExp(r'^\s*(dr|cr)\b\.?\s*', caseSensitive: false);
  static final RegExp _digitSpan = RegExp(r'\d[\d.,\s]*\d|\d');
  static final RegExp _grouped = RegExp(r'^\d{1,3}(,\d{2,3})+(\.\d+)?$');

  /// Most integer digits a real amount has; more is a misread cell.
  static const maxIntegerDigits = 13;

  /// The amount in [cell], or null when it holds none. Handles `1,23,456.78`,
  /// `₹ 500`, `Rs.250`, `(250.00)`, `-99`, `99-`, `+500`, `500.00 Cr`,
  /// `Dr 250`, decimal commas (`1.234,56`) and amounts with no decimals. An
  /// exponent (`1e1000`) is rejected.
  static AmountCell? parse(String cell) {
    var t = cell.trim();
    if (t.isEmpty) return null;
    var sign = AmountSign.unknown;

    final suffix = _suffix.firstMatch(t);
    if (suffix != null) {
      sign = suffix.group(1)!.toLowerCase() == 'dr'
          ? AmountSign.debit
          : AmountSign.credit;
      t = t.substring(0, suffix.start).trim();
    } else {
      final prefix = _prefix.firstMatch(t);
      if (prefix != null) {
        sign = prefix.group(1)!.toLowerCase() == 'dr'
            ? AmountSign.debit
            : AmountSign.credit;
        t = t.substring(prefix.end).trim();
      }
    }

    final span = _digitSpan.firstMatch(t);
    if (span == null) return null;
    final before = t.substring(0, span.start);
    final after = t.substring(span.end);
    // Anything but currency marks, spaces and signs around the number means
    // this is not an amount cell (a reference, a sentence, an exponent).
    final around = RegExp(
      r'^[\s₹$(\-+.:]*(?:rs|inr)?[\s₹$(\-+.:]*$',
      caseSensitive: false,
    );
    final afterOk = RegExp(r'^[\s)\-+.]*$');
    if (!around.hasMatch(before) || !afterOk.hasMatch(after)) return null;

    if (sign == AmountSign.unknown) {
      if (before.contains('(') && after.contains(')')) {
        sign = AmountSign.debit;
      } else if (before.contains('-') || after.trim().endsWith('-')) {
        sign = AmountSign.debit;
      } else if (before.contains('+')) {
        sign = AmountSign.credit;
      }
    }

    var n = span.group(0)!.replaceAll(RegExp(r'\s'), '');
    if (n.contains(',') && n.contains('.')) {
      if (n.lastIndexOf(',') > n.lastIndexOf('.') &&
          RegExp(r',\d{1,2}$').hasMatch(n)) {
        n = n.replaceAll('.', '').replaceFirst(RegExp(r',(?=\d{1,2}$)'), '.');
      } else {
        n = n.replaceAll(',', '');
      }
    } else if (n.contains(',')) {
      if (_grouped.hasMatch(n)) {
        n = n.replaceAll(',', '');
      } else if (RegExp(r'^\d+,\d{1,2}$').hasMatch(n)) {
        n = n.replaceFirst(',', '.');
      } else {
        n = n.replaceAll(',', '');
      }
    }
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(n)) return null;
    final parts = n.split('.');
    if (parts[0].replaceFirst(RegExp('^0+'), '').length > maxIntegerDigits) {
      return null;
    }
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;
    var frac = parts.length > 1 ? parts[1] : '';
    var minor = whole * 100;
    if (frac.isNotEmpty) {
      // Half-up to paise.
      final padded = frac.padRight(3, '0');
      minor += int.parse(padded.substring(0, 2));
      if (int.parse(padded[2]) >= 5) minor += 1;
    }
    frac = '';
    return AmountCell(minor, sign);
  }

  /// A balance cell: negative for a `Dr` suffix, brackets or a minus sign.
  static int? parseBalance(String cell) {
    final a = parse(cell);
    if (a == null) return null;
    return a.sign == AmountSign.debit ? -a.minor : a.minor;
  }
}

/// The date patterns a statement can use, in the order they are tried: day
/// before month, because that is how Indian banks write (FR-05-28).
abstract final class StatementDateFormats {
  /// Pseudo-format: an Excel day number.
  static const serial = 'serial';

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
    'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  // What may follow a date: nothing, or a time after a space, T or comma.
  static const _tail = r'(?=$|[\sT,])';

  static final Map<String, RegExp> _patterns = {
    'dd/MM/yyyy': RegExp(r'^\s*(\d{1,2})/(\d{1,2})/(\d{4})' + _tail),
    'dd-MM-yyyy': RegExp(r'^\s*(\d{1,2})-(\d{1,2})-(\d{4})' + _tail),
    'dd.MM.yyyy': RegExp(r'^\s*(\d{1,2})\.(\d{1,2})\.(\d{4})' + _tail),
    'dd/MM/yy': RegExp(r'^\s*(\d{1,2})/(\d{1,2})/(\d{2})' + _tail),
    'dd-MM-yy': RegExp(r'^\s*(\d{1,2})-(\d{1,2})-(\d{2})' + _tail),
    'dd-MMM-yyyy': RegExp(r'^\s*(\d{1,2})-([A-Za-z]{3,4})-(\d{4})' + _tail),
    'dd-MMM-yy': RegExp(r'^\s*(\d{1,2})-([A-Za-z]{3,4})-(\d{2})' + _tail),
    'dd MMM yyyy': RegExp(r'^\s*(\d{1,2})\s+([A-Za-z]{3,4})\s+(\d{4})' + _tail),
    'dd MMM yy': RegExp(r'^\s*(\d{1,2})\s+([A-Za-z]{3,4})\s+(\d{2})' + _tail),
    'dd/MMM/yyyy': RegExp(r'^\s*(\d{1,2})/([A-Za-z]{3,4})/(\d{4})' + _tail),
    'yyyy-MM-dd': RegExp(r'^\s*(\d{4})-(\d{1,2})-(\d{1,2})' + _tail),
    'yyyy/MM/dd': RegExp(r'^\s*(\d{4})/(\d{1,2})/(\d{1,2})' + _tail),
    'MM/dd/yyyy': RegExp(r'^\s*(\d{1,2})/(\d{1,2})/(\d{4})' + _tail),
    'MMM dd, yyyy':
        RegExp(r'^\s*([A-Za-z]{3,4})\s+(\d{1,2}),?\s+(\d{4})' + _tail),
  };

  /// Every pattern name, in the order automatic detection prefers.
  static List<String> get names => [..._patterns.keys, serial];

  /// Earliest and latest year read as a transaction year.
  static const minYear = 1990;

  /// See [minYear].
  static const maxYear = 2100;

  /// The epoch day of [cell] under [format], or null.
  static int? parse(String cell, String format) {
    if (format == serial) return _serial(cell);
    final re = _patterns[format];
    if (re == null) return null;
    final m = re.firstMatch(cell);
    if (m == null) return null;
    int? day;
    int? month;
    int? year;
    switch (format) {
      case 'yyyy-MM-dd':
      case 'yyyy/MM/dd':
        year = int.parse(m.group(1)!);
        month = int.parse(m.group(2)!);
        day = int.parse(m.group(3)!);
      case 'MM/dd/yyyy':
        month = int.parse(m.group(1)!);
        day = int.parse(m.group(2)!);
        year = int.parse(m.group(3)!);
      case 'MMM dd, yyyy':
        month = _months[m.group(1)!.toLowerCase()];
        day = int.parse(m.group(2)!);
        year = int.parse(m.group(3)!);
      default:
        day = int.parse(m.group(1)!);
        final mid = m.group(2)!;
        month = int.tryParse(mid) ?? _months[mid.toLowerCase()];
        year = int.parse(m.group(3)!);
        if (m.group(3)!.length == 2) year += 2000;
    }
    return _epochDay(year, month, day);
  }

  static int? _epochDay(int year, int? month, int day) {
    if (month == null || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    if (year < minYear || year > maxYear) return null;
    final dt = DateTime.utc(year, month, day);
    // 31 Feb rolls over; a real date round-trips.
    if (dt.month != month || dt.day != day) return null;
    return dt.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  static int? _serial(String cell) {
    final t = cell.trim();
    if (!RegExp(r'^\d{4,6}(\.\d+)?$').hasMatch(t)) return null;
    final n = double.parse(t).floor();
    // Excel day 1 is 1900-01-01 with a phantom 1900-02-29; 25569 is 1970.
    final epoch = n - 25569;
    final year = DateTime.utc(1970).add(Duration(days: epoch)).year;
    return year < minYear || year > maxYear ? null : epoch;
  }

  /// The pattern that reads the most of [cells] (up to 200 non-blank ones):
  /// serials when more than half are plain numbers, else the pattern with the
  /// most parses, ties to the earlier pattern. Null when nothing parses.
  static String? detect(Iterable<String> cells) {
    final sample = [
      for (final c in cells)
        if (c.trim().isNotEmpty) c,
    ].take(200).toList();
    if (sample.isEmpty) return null;
    final numeric =
        sample.where((c) => RegExp(r'^\s*\d+(\.\d+)?\s*$').hasMatch(c)).length;
    if (numeric * 2 > sample.length) {
      final ok = sample.where((c) => _serial(c) != null).length;
      return ok == 0 ? null : serial;
    }
    String? best;
    var bestCount = 0;
    for (final f in _patterns.keys) {
      var n = 0;
      for (final c in sample) {
        if (parse(c, f) != null) n++;
      }
      if (n > bestCount) {
        best = f;
        bestCount = n;
      }
    }
    return best;
  }

  /// A civil date for an epoch day.
  static CivilDate civil(int epochDay) => CivilDate.ofEpochDay(epochDay);
}

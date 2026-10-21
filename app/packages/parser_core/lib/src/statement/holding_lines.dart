import 'package:parser_core/src/statement/figures.dart';
import 'package:parser_core/src/util/strings.dart';

/// One holdings-table row read by [HoldingLines.read].
class HoldingRow {
  /// Creates a row.
  const HoldingRow(
    this.name,
    this.units,
    this.valueMinor,
    this.investedMinor, {
    required this.consistent,
  });

  /// Cleaned scheme or security name.
  final String name;

  /// Units or shares.
  final double? units;

  /// Current value, paise.
  final int? valueMinor;

  /// Amount invested, paise.
  final int? investedMinor;

  /// True when units x price = value was found, so the figures are certainly
  /// the right columns.
  final bool consistent;
}

/// Reads the figures of one holdings-table row in a CAS or broker statement,
/// whatever the column order:
///
///  - CDSL/NSDL demat: `INE002A01018 RELIANCE INDUSTRIES LTD 10.000 -- -- 10.000 2,950.25 29,502.50`
///  - CDSL MF (with the RTA): `Parag Parikh Flexi Cap Fund - Direct Growth INF879O01027 12345678/90 1,234.567 78.1234 80,000.00 96,445.12 16,445.12 14.2%`
///  - NSDL MF folios: `INF179K01BE2 HDFC Mid-Cap Fund - Direct Growth 1234567/89 500.000 50.00 25,000.00 150.234 75,117.00 50,117.00`
///
/// The trailing run of numbers holds the units first. The value is the number
/// that equals units x some price (NAV or market price) to the right of it;
/// when several such pairs exist, the right-most one is the current value and
/// an earlier one, or a number between the price and the value, is the amount
/// invested.
abstract final class HoldingLines {
  static final RegExp _numeric =
      RegExp(r'^\(?-?(?:\d{1,3}(?:,\d{2,3})+|\d+)(?:\.\d+)?\)?$');
  static final RegExp _placeholder = RegExp(
    r'^(?:-+|--|NA|N\.A\.?|NIL|[\d.,]+%|\(?-?[\d.,]+%\)?)$',
    caseSensitive: false,
  );
  static final RegExp _currency =
      RegExp(r'^(?:INR|Rs\.?|₹)$', caseSensitive: false);
  static final RegExp _folio = RegExp(r'^[\d/]+$');
  static final RegExp _ws = RegExp(r'\s+');
  static final RegExp _leadingSerial = RegExp(r'^(?:\d{1,3}[.)]?\s+)+');
  static final RegExp _trailingJunk = RegExp(r'[\s#*|:-]+$');

  static bool _allDigits(String s) => s.split('').every(isDigit);

  /// Splits [after] (the text after the ISIN) into name words and figures,
  /// and reads them.
  static HoldingRow? read(String before, String after) {
    final tokens = after.split(_ws).where((t) => t.isNotEmpty).toList();
    // The trailing run: numbers, dashes, percentages and currency words, read
    // from the end.
    var start = tokens.length;
    while (start > 0) {
      final t = trimChars(tokens[start - 1], ',;|');
      if (_numeric.hasMatch(t) ||
          _placeholder.hasMatch(t) ||
          _currency.hasMatch(t)) {
        start--;
      } else {
        break;
      }
    }
    final run = tokens
        .sublist(start)
        .map((t) => trimChars(t, ',;|'))
        .where((t) => !_currency.hasMatch(t))
        .toList();
    // Placeholders keep their column, but count as no number.
    final nums = <double?>[
      for (final t in run)
        if (_numeric.hasMatch(t)) number(t) else null,
    ];
    final raw = [...run];
    // A folio number made of digits only ("91012345678") sits before the
    // units: never a quantity.
    while (raw.isNotEmpty &&
        raw.length > 2 &&
        _allDigits(raw[0]) &&
        raw[0].length >= 6) {
      raw.removeAt(0);
      nums.removeAt(0);
    }

    // Name words, without a folio number ("12345678/90", "91012345678"); a
    // short number stays ("NIFTY 50").
    final wordsAfter = tokens
        .sublist(0, start)
        .where(
          (t) => !(_folio.hasMatch(t) && (t.contains('/') || t.length >= 6)),
        )
        .join(' ');
    final name = cleanName(
      [before, wordsAfter].where((s) => s.trim().isNotEmpty).join(' '),
    );
    if (nums.where((n) => n != null).length < 2) return null;

    // Try the units at the first or second number (a name may end in a
    // number: "NIFTY 50").
    final lastS = nums.length - 2 < 1 ? nums.length - 2 : 1;
    for (var s = 0; s <= lastS; s++) {
      final units = nums[s];
      if (units == null || units <= 0) continue;
      final pairs = <(int, int)>[];
      for (var i = s + 1; i < nums.length; i++) {
        final price = nums[i];
        if (price == null || price <= 0) continue;
        for (var j = i + 1; j < nums.length; j++) {
          final v = nums[j];
          if (v == null || v <= 0) continue;
          final tol = v * 0.015 > 1.0 ? v * 0.015 : 1.0;
          if ((units * price - v).abs() <= tol) pairs.add((i, j));
        }
      }
      if (pairs.isEmpty) continue;
      var best = pairs.first;
      for (final p in pairs) {
        if (p.$2 > best.$2) best = p;
      }
      final value = nums[best.$2]!;
      // Invested: an earlier units x average-cost pair, else a number between
      // the price and the value.
      final earlier =
          pairs.where((p) => p.$2 < best.$2 && p.$2 != best.$1).toList();
      double? invested;
      if (earlier.isNotEmpty) {
        var e = earlier.first;
        for (final p in earlier) {
          if (p.$2 < e.$2) e = p;
        }
        invested = nums[e.$2];
      } else {
        for (var k = best.$1 + 1; k < best.$2; k++) {
          final n = nums[k];
          if (n != null && n > 0 && n < value * 20) {
            invested = n;
            break;
          }
        }
      }
      final extraName = s == 1 ? raw[0] : '';
      return HoldingRow(
        cleanName(
          [name, extraName].where((x) => x.trim().isNotEmpty).join(' '),
        ),
        units,
        paise(value),
        invested == null ? null : paise(invested),
        consistent: true,
      );
    }
    // No price column found: units first, value last.
    final present = nums.whereType<double>().toList();
    final value = present.last;
    if (value <= 0) return null;
    return HoldingRow(
      name,
      present.first,
      paise(value),
      null,
      consistent: false,
    );
  }

  /// A figure: plain, grouped, in brackets (negative) or with a leading minus.
  static double? number(String t) {
    final negative = t.startsWith('(') || t.startsWith('-');
    final v = parseDouble(trimChars(t, '()-').replaceAll(',', ''));
    if (v == null) return null;
    return negative ? -v : v;
  }

  /// CDSL names a demat holding "RELIANCE INDUSTRIES LIMITED#EQUITY SHARES":
  /// the part before '#' is the name.
  static String cleanName(String s) {
    final hash = s.indexOf('#');
    var n = hash < 0 ? s : s.substring(0, hash);
    if (n.trim().isEmpty) n = s;
    n = n
        .replaceAll(_ws, ' ')
        .replaceAll(_leadingSerial, '')
        .replaceAll('#', ' ')
        .replaceAll(_ws, ' ')
        .replaceAll(_trailingJunk, '')
        .trim();
    return trimChars(n, '-|: ');
  }
}

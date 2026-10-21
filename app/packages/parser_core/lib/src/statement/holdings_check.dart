import 'package:parser_core/src/model/holding.dart';
import 'package:parser_core/src/statement/figures.dart';
import 'package:parser_core/src/statement/holding_lines.dart';
import 'package:parser_core/src/statement/holding_table.dart';
import 'package:parser_core/src/text/rx.dart';

/// The totals a holdings sheet states in its summary block ("Total
/// Investments", "Current Portfolio Value") beside what the rows add up to.
/// [mismatch] is set when a stated total and the rows' sum differ by more than
/// [toleranceMinor]; the rows are recorded regardless. A figure the rows do
/// not carry is null, never made up (FR-05-18).
class HoldingsCheck {
  /// Creates a check.
  const HoldingsCheck({
    required this.statedInvestedMinor,
    required this.statedValueMinor,
    required this.rowsInvestedMinor,
    required this.rowsValueMinor,
    required this.mismatch,
  });

  /// One rupee.
  static const int toleranceMinor = 100;

  /// Stated total invested, paise.
  final int? statedInvestedMinor;

  /// Stated current value, paise.
  final int? statedValueMinor;

  /// Sum of the rows' invested, paise.
  final int? rowsInvestedMinor;

  /// Sum of the rows' value, paise.
  final int? rowsValueMinor;

  /// A stated total and the rows differ by more than [toleranceMinor].
  final bool mismatch;
}

enum _Key { invested, value, other }

/// Reads the summary block of a holdings sheet and compares it to the rows read.
abstract final class HoldingsCheckReader {
  static final List<(_Key, RegExp)> _labels = [
    (
      _Key.invested,
      rx(r'total\s+investments?|investments?\s+(?:value|amount)|invested\s+(?:value|amount)|\binvested\b|total\s+cost'),
    ),
    (
      _Key.value,
      rx(r'current\s+(?:portfolio\s+|market\s+)?(?:value|amount)|portfolio\s+value|market\s+value|total\s+value'),
    ),
    (
      _Key.other,
      rx(r'profit\s*/?\s*loss\s*%?|\bP\s*&\s*L\b|\bxirr\b|\breturns?\s*%?|\bgains?\b'),
    ),
  ];
  static final RegExp _tableWords =
      rx(r'\b(?:scheme|fund|name|folio|units?|symbol|instrument|isin)\b');
  static final RegExp _figure = RegExp(
    r'^(?:₹|Rs\.?|INR)?\(?[+-]?(?:\d{1,3}(?:,\d{2,3})+|\d+)(?:\.\d+)?\)?\s*%?$',
    caseSensitive: false,
  );
  static final RegExp _cells = RegExp(r'\s{2,}|\t|\||¦');
  static final RegExp _currencyHead =
      RegExp(r'^(?:₹|Rs\.?|INR)', caseSensitive: false);

  /// The check for [lines] and the [holdings] read from them; null when the
  /// sheet states no totals.
  static HoldingsCheck? check(
    List<String> lines,
    List<HoldingSnapshot> holdings,
  ) {
    final (invested, value) = stated(lines);
    if (invested == null && value == null) return null;
    final ri = holdings.map((h) => h.investedMinor).whereType<int>().toList();
    final rv = holdings.map((h) => h.valueMinor).whereType<int>().toList();
    final rowsInvested = ri.isEmpty ? null : ri.fold<int>(0, (a, b) => a + b);
    final rowsValue = rv.isEmpty ? null : rv.fold<int>(0, (a, b) => a + b);
    bool off(int? s, int? r) =>
        s != null && r != null && (s - r).abs() > HoldingsCheck.toleranceMinor;
    return HoldingsCheck(
      statedInvestedMinor: invested,
      statedValueMinor: value,
      rowsInvestedMinor: rowsInvested,
      rowsValueMinor: rowsValue,
      mismatch: off(invested, rowsInvested) || off(value, rowsValue),
    );
  }

  /// Stated total invested and current value, in paise: a label row over a
  /// figures row, or "label  figure" rows.
  static (int?, int?) stated(List<String> lines) {
    int? invested;
    int? value;
    void put(_Key k, double? v) {
      if (v == null) return;
      final m = paise(v);
      if (k == _Key.invested && invested == null) invested = m;
      if (k == _Key.value && value == null) value = m;
    }

    for (var i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.length > 160 || _tableWords.hasMatch(text)) continue;
      final labels = scanLabels(text, _labels);
      if (labels.isEmpty) continue;
      final tail = text.substring(labels.last.last + 1);
      if (labels.length == 1 &&
          labels[0].first == 0 &&
          labels[0].key != _Key.other) {
        // "Total Investments  12500.5"
        final c = _cellsOf(tail);
        if (c.isNotEmpty) put(labels[0].key, _number(c.first));
        continue;
      }
      if (labels.length < 2) continue;
      // Labels on this line, their figures on the next.
      final next = _cellsOf(i + 1 < lines.length ? lines[i + 1] : '');
      if (next.isEmpty || !next.every(_figure.hasMatch)) continue;
      if (next.length == labels.length) {
        for (var j = 0; j < labels.length; j++) {
          put(labels[j].key, _number(next[j]));
        }
      } else if (labels[0].key == _Key.invested &&
          labels[1].key == _Key.value &&
          next.length >= 2) {
        put(_Key.invested, _number(next[0]));
        put(_Key.value, _number(next[1]));
      }
    }
    return (invested, value);
  }

  static List<String> _cellsOf(String s) {
    final out = <String>[];
    for (final c in s
        .trim()
        .split(_cells)
        .map((x) => x.trim())
        .where((x) => x.isNotEmpty)) {
      final parts = c.split(' ');
      if (c.contains(' ') && parts.every(_figure.hasMatch)) {
        out.addAll(parts);
      } else {
        out.add(c);
      }
    }
    return out;
  }

  static double? _number(String t) => HoldingLines.number(
        t.replaceAll('%', '').replaceFirst(_currencyHead, '').trim(),
      );
}

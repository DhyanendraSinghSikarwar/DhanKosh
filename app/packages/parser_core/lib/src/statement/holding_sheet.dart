import 'package:parser_core/src/model/holding.dart';
import 'package:parser_core/src/statement/figures.dart';
import 'package:parser_core/src/statement/holding_columns.dart';
import 'package:parser_core/src/statement/mf_order_parser.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// Holdings read by column from a spreadsheet (`SpreadsheetLines` keeps the
/// cells of such a sheet apart with [sep]). The header row is found by
/// `HoldingColumns`, so Groww, Zerodha, Kuvera, INDmoney, broker and registrar
/// exports all go the same way. Cells may be text ("1250.75", "4.1%",
/// "(1,500)", "Rs 1,200 Cr"); folio numbers and ISINs are never read as
/// amounts. Missing figures are worked out only from others on the row
/// (invested = units x average price, current = units x price); nothing is
/// made up. Rows of one scheme or stock in several folios or lots are summed.
abstract final class HoldingSheet {
  /// Separates the cells of a sheet row in the text lines.
  static const String sep = '¦';

  static final RegExp _total =
      rx(r'^(?:grand\s+|sub\s*-?\s*)?totals?\b|\bportfolio\s+total\b');
  static final RegExp _isin = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}\d$');
  static final RegExp _commodity =
      rx(r'\bcommodit(?:y|ies)\b|\b(?:gold|silver)\b');
  static final RegExp _etfName = rx(r'\bETF\b|\bBEES\b');
  static final RegExp _fundWords =
      rx(r'\b(?:fund|scheme|plan|growth|IDCW|FoF|index|dividend)\b');
  static final RegExp _placeholder =
      RegExp(r'^(?:-+|NA|N/A|N\.A\.?|NIL|NULL)$', caseSensitive: false);
  static final RegExp _currency =
      RegExp(r'^(?:₹|Rs\.?|INR)\s*', caseSensitive: false);
  static final RegExp _plain = RegExp(r'^[+-]?\d+(?:\.\d+)?$');
  static final RegExp _crDr = rx(r'\s*(Cr|Dr)\.?$');
  static final RegExp _ws = RegExp(r'\s+');

  /// True when [line] is a sheet row in cell form.
  static bool isRow(String line) => line.contains(sep);

  /// The trimmed cells of a sheet row.
  static List<String> cells(String line) =>
      line.split(sep).map((c) => c.trim()).toList();

  /// A figure in a cell: plain, grouped, with a currency sign, in brackets, or
  /// with Cr/Dr; null for text, "-" and percentages.
  static double? number(String raw, {bool allowPct = false}) {
    var s = raw.trim().replaceAll(' ', ' ');
    if (s.isEmpty || _placeholder.hasMatch(s)) return null;
    if (s.endsWith('%')) {
      if (!allowPct) return null;
      s = s.substring(0, s.length - 1).trim();
    }
    var negative = false;
    final tail = _crDr.firstMatch(s);
    if (tail != null) {
      negative = grp(tail, 1).toLowerCase() == 'dr';
      s = s.substring(0, tail.start);
    }
    s = s.trim().replaceFirst(_currency, '').trim();
    if (s.startsWith('(') && s.endsWith(')')) {
      negative = !negative;
      s = s.substring(1, s.length - 1).trim();
    }
    s = s.replaceFirst(_currency, '').replaceAll(',', '').replaceAll(' ', '');
    if (!_plain.hasMatch(s)) return null;
    final v = double.parse(s);
    return negative ? -v : v;
  }

  /// The holdings of every table in [lines], or null when the lines hold no
  /// sheet header (a PDF, or a sheet in dollars): the caller then reads them as
  /// text. [platform] names the app when the sender says so; a Source column
  /// wins.
  static List<HoldingSnapshot>? read(
    List<String> lines,
    int asOf,
    String? platform,
  ) {
    Map<HoldingField, int>? cols;
    var sawHeader = false;
    final out = <String, HoldingSnapshot>{};
    final platforms = <String, Set<String>>{};
    for (final line in lines) {
      if (!isRow(line)) continue;
      final cs = cells(line);
      if (cs.every((c) => c.isEmpty)) {
        cols = null;
        continue;
      }
      if (HoldingColumns.isHeader(cs)) {
        cols = HoldingColumns.map(cs);
        sawHeader = true;
        continue;
      }
      final c = cols;
      if (c == null) continue;
      final first = cs.firstWhere((x) => x.isNotEmpty, orElse: () => '');
      if (_total.hasMatch(first)) {
        cols = null;
        continue;
      }
      String cell(HoldingField f) {
        final i = c[f];
        return i == null || i >= cs.length ? '' : cs[i];
      }

      double? num(HoldingField f) => number(cell(f));
      var name = cell(HoldingField.name);
      if (name.isEmpty) name = cell(HoldingField.symbol);
      name = name.replaceAll(_ws, ' ').trim();
      if (name.length < 2 ||
          !name.split('').any(isLetter) ||
          _total.hasMatch(name)) {
        continue;
      }
      final units = num(HoldingField.units);
      final gain = num(HoldingField.gain);
      final investedCell = num(HoldingField.invested);
      var current = num(HoldingField.current);
      if (current == null && units != null) {
        final p = num(HoldingField.price);
        if (p != null) current = units * p;
      }
      if (current == null && investedCell != null && gain != null) {
        current = investedCell + gain;
      }
      if (current == null || current <= 0) continue;
      var invested = investedCell;
      if (invested == null && units != null) {
        final a = num(HoldingField.avgPrice);
        if (a != null) invested = units * a;
      }
      if (invested == null && gain != null) invested = current - gain;
      if (invested != null && invested <= 0) invested = null;
      final isinCell = cell(HoldingField.isin).toUpperCase();
      final isin = _isin.hasMatch(isinCell) ? isinCell : null;
      final category =
          '${cell(HoldingField.category)} ${cell(HoldingField.subCategory)}';
      final equityIsin = isin != null && isin.startsWith('INE');
      final fundish = !equityIsin &&
          ((isin != null && isin.startsWith('INF')) ||
              cell(HoldingField.folio).isNotEmpty ||
              cell(HoldingField.amc).isNotEmpty ||
              _fundWords.hasMatch(name));
      final HoldingKind kind;
      if (!equityIsin &&
          (_commodity.hasMatch(category) ||
              (fundish && _commodity.hasMatch(name)))) {
        kind = HoldingKind.gold;
      } else if (_etfName.hasMatch(name) ||
          category.toLowerCase().contains('etf')) {
        kind = HoldingKind.etf;
      } else if (fundish) {
        kind = HoldingKind.mutualFund;
      } else {
        kind = HoldingKind.stock;
      }
      final id = isin ??
          (kind == HoldingKind.stock
              ? 'STOCK:${MfOrderParser.normaliseScheme(name).toUpperCase()}'
              : MfOrderParser.identifierFor(name));
      final snap = HoldingSnapshot(
        kind: kind,
        name: name,
        identifier: id,
        units: units != null && units > 0 ? units : null,
        valueMinor: paise(current),
        investedMinor: invested == null ? null : paise(invested),
        asOf: asOf,
      );
      var source = cell(HoldingField.source);
      if (source.isEmpty) source = platform ?? '';
      if (source.isNotEmpty) {
        platforms.putIfAbsent(id, () => <String>{}).add(source);
      }
      // One scheme or stock in several folios or lots: the figures add up.
      final p = out[id];
      out[id] = p == null
          ? snap
          : p.withFigures(
              units: p.units == null && snap.units == null
                  ? null
                  : (p.units ?? 0.0) + (snap.units ?? 0.0),
              valueMinor: (p.valueMinor ?? 0) + snap.valueMinor!,
              investedMinor:
                  p.investedMinor == null && snap.investedMinor == null
                      ? null
                      : (p.investedMinor ?? 0) + (snap.investedMinor ?? 0),
            );
    }
    if (!sawHeader) return null;
    return [
      for (final e in out.entries)
        e.value.withPlatform(platforms[e.key]?.join(', ')),
    ];
  }
}

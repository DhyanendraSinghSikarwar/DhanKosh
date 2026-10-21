import 'package:parser_core/src/model/holding.dart';
import 'package:parser_core/src/statement/figures.dart';
import 'package:parser_core/src/statement/holding_lines.dart';
import 'package:parser_core/src/statement/holding_sheet.dart';
import 'package:parser_core/src/statement/mf_order_parser.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

enum _Col {
  units(false),
  avgPrice(false),
  price(false),
  invested(false),
  value(false),
  returns(false),
  pct(true);

  const _Col(this.pct);
  final bool pct;
}

class _Tok {
  const _Tok(this.value, {required this.pct});
  final double? value;
  final bool pct;
}

/// A label found by [scanLabels]: [first] and [last] are inclusive offsets.
class LabelHit<K> {
  /// Creates a hit.
  const LabelHit(this.key, this.first, this.last);

  /// The label's key.
  final K key;

  /// Offset of the first character.
  final int first;

  /// Offset of the last character.
  final int last;
}

/// Non-overlapping label matches, left to right; at one position the longest
/// match wins.
List<LabelHit<K>> scanLabels<K>(String text, List<(K, RegExp)> labels) {
  final out = <LabelHit<K>>[];
  var pos = 0;
  while (pos < text.length) {
    LabelHit<K>? best;
    for (final (k, r) in labels) {
      final m = findFrom(r, text, pos);
      if (m == null) continue;
      final hit = LabelHit<K>(k, m.start, m.end - 1);
      if (best == null ||
          hit.first < best.first ||
          (hit.first == best.first && hit.last > best.last)) {
        best = hit;
      }
    }
    if (best == null) break;
    out.add(best);
    pos = best.last + 1;
  }
  return out;
}

/// Holdings tables whose rows carry no ISIN: Groww's mutual fund "Holdings
/// statement" (PDF or XLSX) and similar app statements. A header row names the
/// figure columns ("Scheme Name  AMC  Category  Folio No.  Units  Invested
/// Value  Current Value  Returns  XIRR"); each row below it ends in those
/// figures. The figures are matched to the columns so that they agree with each
/// other (invested + returns = current value, units x NAV = value), which
/// survives a blank cell or a column the PDF text left out.
///
/// A table in US dollars (INDmoney's US stocks statement: "Invested Value ($)",
/// "$575.25") is converted at the statement's own USD/INR rate; without one its
/// rows are left out rather than counted as rupees.
abstract final class HoldingTable {
  static final List<(_Col, RegExp)> _labels = [
    (
      _Col.invested,
      rx(r'invested\s+(?:value|amount|amt)|amount\s+invested|investment\s+(?:value|amount|cost)|total\s+investments?|cost\s+value|purchase\s+value|total\s+cost|buy\s+value|\binvested\b|\bcost\b'),
    ),
    (
      _Col.value,
      rx(r'current\s+(?:market\s+|portfolio\s+)?(?:value|valuation|val\b|amount|amt)|cur\.?\s*val\b\.?|market\s+(?:value|val\b)|present\s+value|closing\s+value|\bvaluation\b|\bvalue\b|\bcurrent\b'),
    ),
    (
      _Col.avgPrice,
      rx(r'avg\.?\s+(?:buy\s+)?(?:nav|price|cost)|average\s+(?:buy\s+)?(?:nav|price|cost)|buy\s+(?:nav|price)|purchase\s+(?:nav|price)'),
    ),
    (
      _Col.price,
      rx(r'(?:current|latest|closing|market)\s+(?:nav|price)|\bNAV\b|\bLTP\b'),
    ),
    (
      _Col.units,
      rx(r'\b(?:balance\s+|closing\s+)?units?\b|\bquantity\b|\bqty\b'),
    ),
    (
      _Col.pct,
      rx(r'(?:profit|P\s*&\s*L|gains?)(?:\s*/\s*\(?loss\)?)?\s*\(?%\)?|\bXIRR\b|\bCAGR\b|returns?\s*\(\s*%\s*\)|returns?\s*%|%\s*returns?|abs(?:olute)?\.?\s+returns?|gain\s*\(?%\)?'),
    ),
    (
      _Col.returns,
      rx(r'unreali[sz]ed\s+(?:P\s*&\s*L|gains?(?:\s*/\s*\(?loss\)?)?|profit(?:\s*/\s*\(?loss\)?)?)|\breturns?\b|\bgains?(?:\s*/\s*\(?loss\)?)?|\bP\s*&\s*L\b|\bprofit(?:\s*/\s*\(?loss\)?)?|unreali[sz]ed'),
    ),
  ];
  static final RegExp _nameHead = rx(
    r'\b(?:scheme|fund|security|instrument|stock|company|holding|name|symbol|isin|scrip|script)\b',
  );
  static final RegExp _fundHead = rx(r'\b(?:scheme|fund|folio|NAV|AMC)\b');
  static final RegExp _total = rx(
    r'^(?:grand\s+|sub\s*-?\s*)?total\b|\btotal\s*:|\bportfolio\s+(?:value|total)\b',
  );
  static final RegExp _fundWords =
      rx(r'\b(?:fund|scheme|plan|growth|IDCW|ETF|FoF|index|dividend)\b');
  static final RegExp _etfName = rx(r'\bETF\b|\bBEES\b');
  static final RegExp _nameEnd = rx(
    r'^(.*?\b(?:Growth|IDCW|Dividend|Bonus)(?:\s+(?:Option|Plan|Payout|Reinvestment))?)\b',
  );
  static final RegExp _isin = RegExp(r'\b[A-Z]{2}[A-Z0-9]{9}\d\b');
  static final RegExp _commodity = rx(r'\bcommodit(?:y|ies)\b|\b(?:gold|silver)\b');
  static final RegExp _cells = RegExp(r'\s{2,}');
  static final RegExp _ws = RegExp(r'\s+');

  static final RegExp _numeric =
      RegExp(r'^[+-]?\(?[+-]?(?:\d{1,3}(?:,\d{2,3})+|\d+)(?:\.\d+)?\)?$');
  static final RegExp _percent = RegExp(r'^\(?[+-]?\d[\d,]*(?:\.\d+)?\s*%\)?$');
  static final RegExp _placeholder =
      RegExp(r'^(?:-+|NA|N/A|N\.A\.?|NIL)$', caseSensitive: false);
  static final RegExp _currency =
      RegExp(r'^(?:INR|Rs\.?|₹|USD|US\$|\$)$', caseSensitive: false);
  static final RegExp _currencyPrefix =
      RegExp(r'^(?:₹|Rs\.?|INR|US\$|\$|USD)(?=[\d(+-])', caseSensitive: false);
  static final RegExp _usdHead =
      RegExp(r'\$|\bUSD\b|\bUS\s+stocks?\b', caseSensitive: false);
  static final RegExp _ticker = RegExp(r'^[A-Z]{1,5}(?:\.[A-Z])?$');

  /// Holdings from every table in [lines] whose header names invested and
  /// current value. Rows with an ISIN are left to the caller ([hasIsin] says
  /// which).
  static List<HoldingSnapshot> read(
    List<String> lines,
    int asOf, {
    double? usdRate,
    String? platform,
    required bool Function(String) hasIsin,
  }) {
    final sheet = HoldingSheet.read(lines, asOf, platform);
    if (sheet != null) return sheet;
    final out = <String, HoldingSnapshot>{};
    List<_Col>? cols;
    var fundTable = false;
    // Rupees per figure: 1 in a rupee table, the USD rate in a dollar table,
    // null in a dollar table without a rate.
    double? rate = 1;
    String? pending;
    var skip = -1;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i == skip) continue;
      // The header, on one line or wrapped onto the next.
      var head = _header(line);
      if (head == null &&
          i + 1 < lines.length &&
          _nameHead.hasMatch(line)) {
        head = _header('$line ${lines[i + 1]}');
        if (head != null) skip = i + 1;
      }
      if (head != null) {
        cols = head;
        final headText = skip == i + 1 ? '$line ${lines[i + 1]}' : line;
        fundTable = _fundHead.hasMatch(
          '$line ${i + 1 < lines.length ? lines[i + 1] : ''}',
        );
        rate = _usdHead.hasMatch(headText) ? usdRate : 1;
        pending = null;
        continue;
      }
      final c = cols;
      if (c == null) continue;
      final fx = rate;
      if (fx == null) continue;
      String? isin;
      var row = line;
      if (hasIsin(line)) {
        final m = _isin.firstMatch(line);
        if (m == null) continue;
        isin = m.group(0);
        row = line.replaceAll(isin!, ' ');
      }
      if (_total.hasMatch(line.trim())) {
        pending = null;
        continue;
      }
      final (namePart, toks) = _split(row);
      if (toks.where((t) => t.value != null).length < 2) {
        // A name on its own line, its figures on the next.
        pending = namePart.split('').any(isLetter) && namePart.length < 120
            ? namePart
            : null;
        continue;
      }
      final fig = _align(toks, c);
      if (fig == null) continue;
      var name = _name(row, namePart);
      if (pending != null &&
          (!name.split('').any(isLetter) || name.split(' ').length <= 2)) {
        name = HoldingLines.cleanName('$pending $name');
      }
      pending = null;
      if (name.length < 3 || _total.hasMatch(name)) continue;
      final v = fig[_Col.value];
      if (v == null) continue;
      final value = v * fx;
      if (value <= 0) continue;
      double? invested;
      final inv = fig[_Col.invested];
      if (inv != null && inv > 0) {
        invested = inv * fx;
      } else {
        final r = fig[_Col.returns];
        if (r != null) {
          final x = value - r * fx;
          if (x > 0) invested = x;
        }
      }
      final u = fig[_Col.units];
      final units = u != null && u > 0 ? u : null;
      final HoldingKind kind;
      if (_commodity.hasMatch(line)) {
        kind = HoldingKind.gold;
      } else if (_etfName.hasMatch(name)) {
        kind = HoldingKind.etf;
      } else if (fundTable || _fundWords.hasMatch(name)) {
        kind = HoldingKind.mutualFund;
      } else {
        kind = HoldingKind.stock;
      }
      final String id;
      if (fx != 1.0 && kind != HoldingKind.mutualFund) {
        final first = name.split(' ').first;
        id = 'US:${_ticker.hasMatch(first) ? first : MfOrderParser.normaliseScheme(name).toUpperCase()}';
      } else if (isin != null) {
        id = isin;
      } else if (kind == HoldingKind.stock) {
        id = 'STOCK:${MfOrderParser.normaliseScheme(name).toUpperCase()}';
      } else {
        id = MfOrderParser.identifierFor(name);
      }
      final snap = HoldingSnapshot(
        kind: kind,
        name: name,
        identifier: id,
        units: units,
        valueMinor: paise(value),
        investedMinor: invested == null ? null : paise(invested),
        asOf: asOf,
      );
      // One scheme in two folios: the folios add up.
      final p = out[id];
      out[id] = p == null
          ? snap
          : p.withFigures(
              units: p.units == null && units == null
                  ? null
                  : (p.units ?? 0.0) + (units ?? 0.0),
              valueMinor: (p.valueMinor ?? 0) + snap.valueMinor!,
              investedMinor: p.investedMinor == null && snap.investedMinor == null
                  ? null
                  : (p.investedMinor ?? 0) + (snap.investedMinor ?? 0),
            );
    }
    return out.values.toList();
  }

  /// The figure columns a header line names, in order; null unless it names
  /// both invested and current value.
  static List<_Col>? _header(String line) {
    if (!_nameHead.hasMatch(line) && !line.toLowerCase().contains('units')) {
      return null;
    }
    final cols = scanLabels(line, _labels).map((h) => h.key).toList();
    if (!cols.contains(_Col.value) ||
        (!cols.contains(_Col.invested) && !cols.contains(_Col.units))) {
      return null;
    }
    // A header has words, not figures.
    if (line
        .split(_ws)
        .any((w) => _numeric.hasMatch(trimChars(w, ',')) && w.contains('.'))) {
      return null;
    }
    return cols;
  }

  /// The words before the trailing run of figures, and the figures.
  static (String, List<_Tok>) _split(String line) {
    final tokens = line.split(_ws).where((t) => t.isNotEmpty).toList();
    String clean(String t) =>
        trimChars(t, ',;|').replaceFirst(_currencyPrefix, '');
    var start = tokens.length;
    while (start > 0) {
      final t = clean(tokens[start - 1]);
      if (_numeric.hasMatch(t) ||
          _percent.hasMatch(t) ||
          _placeholder.hasMatch(t) ||
          _currency.hasMatch(t)) {
        start--;
      } else {
        break;
      }
    }
    final toks = <_Tok>[
      for (final raw in tokens.sublist(start))
        if (!_currency.hasMatch(clean(raw)))
          _tokOf(clean(raw)),
    ];
    return (tokens.sublist(0, start).join(' '), toks);
  }

  static _Tok _tokOf(String t) {
    if (_percent.hasMatch(t)) {
      return _Tok(
        HoldingLines.number(t.replaceAll('%', '').replaceAll(' ', '')),
        pct: true,
      );
    }
    if (_numeric.hasMatch(t)) {
      return _Tok(HoldingLines.number(t.replaceAll('+', '')), pct: false);
    }
    return const _Tok(null, pct: false);
  }

  /// The row's name: a spreadsheet row's first text cell, or a PDF row's words
  /// up to "Growth" / "IDCW".
  static String _name(String line, String namePart) {
    final cs = line.trim().split(_cells);
    if (cs.length >= 3) {
      for (final c in cs) {
        if (c.split('').any(isLetter) && !_numeric.hasMatch(c)) {
          return HoldingLines.cleanName(c);
        }
      }
    }
    final words = namePart
        .split(' ')
        .where((w) => !(w.split('').every((ch) => isDigit(ch) || ch == '/') &&
            w.length >= 6))
        .join(' ');
    final m = _nameEnd.firstMatch(words);
    return HoldingLines.cleanName(m == null ? words : grp(m, 1));
  }

  /// Matches the figures to the columns, in order. Columns may be missing (a
  /// blank cell) and leading figures may be skipped (a folio number); a
  /// percentage only fills a percentage column. The assignment whose figures
  /// agree wins.
  static Map<_Col, double>? _align(List<_Tok> toks, List<_Col> cols) {
    if (toks.length > 12 || cols.isEmpty) return null;
    Map<_Col, double>? best;
    var bestScore = double.negativeInfinity;
    final assigned = List<_Col?>.filled(toks.length, null);

    void evaluate() {
      final map = <_Col, double>{};
      var penalty = 0.0;
      var assignedCount = 0;
      for (var i = 0; i < toks.length; i++) {
        final t = toks[i];
        final c = assigned[i];
        if (c == null) {
          penalty += t.pct ? 0.5 : 1.0;
          continue;
        }
        assignedCount++;
        if (!t.pct && c.pct) penalty += 0.25;
        final v = t.value;
        if (v != null) map[c] = v;
      }
      penalty += (cols.length - assignedCount) * 1.0;
      final value = map[_Col.value];
      if (value == null || value <= 0) return;
      var score = -penalty;
      final inv = map[_Col.invested];
      final ret = map[_Col.returns];
      final units = map[_Col.units];
      final price = map[_Col.price];
      final avg = map[_Col.avgPrice];
      double tol(double v, double f) => v * f > 1.0 ? v * f : 1.0;
      if (inv != null &&
          ret != null &&
          (inv + ret - value).abs() <= tol(value, 0.01)) {
        score += 6;
      }
      if (units != null &&
          price != null &&
          (units * price - value).abs() <= tol(value, 0.015)) {
        score += 6;
      }
      if (units != null &&
          avg != null &&
          inv != null &&
          (units * avg - inv).abs() <= tol(inv, 0.015)) {
        score += 4;
      }
      if (score > bestScore) {
        bestScore = score;
        best = map;
      }
    }

    void go(int ti, int ci) {
      if (ti == toks.length) {
        evaluate();
        return;
      }
      // Skip a figure: a leading folio number, or a percentage beside its
      // amount ("16,445.12 (20.56%)").
      if (toks[ti].pct || assigned.take(ti).every((c) => c == null)) {
        assigned[ti] = null;
        go(ti + 1, ci);
      }
      for (var cj = ci; cj < cols.length; cj++) {
        if (toks[ti].pct && !cols[cj].pct) continue;
        assigned[ti] = cols[cj];
        go(ti + 1, cj + 1);
        assigned[ti] = null;
      }
    }

    go(0, 0);
    return best;
  }
}

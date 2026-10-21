import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/model/holding.dart';
import 'package:parser_core/src/statement/figures.dart';
import 'package:parser_core/src/statement/holding_table.dart';
import 'package:parser_core/src/statement/investment_parser.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

enum _Key { contribution, withdrawal, gain, value, ret }

/// An NPS Statement of Transaction (Protean/NSDL, KFintech or CAMS CRA): the
/// PRAN, the valuation summary ("Total Contribution", "Total Notional
/// Gain/Loss", "Value of your Holdings" or "Total Holding Value") and the
/// scheme-wise units, NAV and value. One holding per tier: "NPS:<last 4 of
/// PRAN>" for Tier I, `NPS:<last 4>:T2` for Tier II.
abstract final class NpsStatement {
  static final RegExp _isNps =
      rx(r'\bNPS\b|national\s+pension|pension\s+fund|\bCRA\b|\bPFRDA\b');
  static final RegExp _pran =
      rx(r'\bPRAN\b(?:\s*(?:No\.?|Number))?[^0-9]{0,20}[x*\d]*?(\d{4})\b');
  static final RegExp _tier = rx(r'\bTier\s*[-:]?\s*(II|2|I|1)\b');
  static final RegExp _schemeRow = rx(
    r'\bscheme\s*[-:]?\s*(?:E|C|G|A)\b|\bpension\s+fund\b|\bscheme\b.{0,60}\btier\b',
  );
  static final List<(_Key, RegExp)> _labels = [
    (
      _Key.contribution,
      rx(r'total\s+contributions?(?:\s+amount)?|contributions?\s+(?:amount\s+)?(?:till\s+date|made)|total\s+amount\s+invested'),
    ),
    (_Key.withdrawal, rx(r'total\s+withdrawals?')),
    (
      _Key.gain,
      rx(r'total\s+notional\s+gain\s*/\s*loss|notional\s+gain\s*/\s*loss|notional\s+gain|gain\s*/\s*loss|total\s+gain'),
    ),
    (
      _Key.value,
      rx(r'value\s+of\s+(?:your\s+)?holdings?(?:\s*\(\s*investment\s*\))?|total\s+holding\s+value|holding\s+value|total\s+value(?:\s+of\s+holdings?)?|current\s+value|total\s+valuation|\bvaluation\b'),
    ),
    (
      _Key.ret,
      rx(r'return\s+on\s+investment(?:\s*\(\s*XIRR\s*\))?|\bXIRR\b'),
    ),
  ];
  static final RegExp _date = rx(
    r'\b\d{1,2}[/.-](?:\d{1,2}|[A-Za-z]{3,9})[/.-]\d{2,4}\b|\b\d{1,2}\s+[A-Za-z]{3,9},?\s+\d{4}\b',
  );
  static final RegExp _amount = RegExp(
    r'(?<![\d.,])(\d{1,3}(?:,\d{2,3})+\.\d{2}|\d+\.\d{2})(?![\d%]|\s*%)',
  );
  static final RegExp _number =
      RegExp(r'(?<![\d.,A-Za-z])\d[\d,]*(?:\.\d+)?(?![\d%A-Za-z])');

  /// Whether [lines] are an NPS statement.
  static bool isNps(List<String> lines) {
    final head = lines.take(60).join(' ');
    return _pran.hasMatch(head) && _isNps.hasMatch(head);
  }

  /// The holdings, one per tier.
  static List<HoldingSnapshot> read(List<String> lines, int asOf) {
    if (!isNps(lines)) return const [];
    String? last4;
    for (final l in lines.take(60)) {
      final m = _pran.firstMatch(l);
      if (m != null) {
        last4 = grp(m, 1);
        break;
      }
    }
    if (last4 == null) return const [];
    final summary = <int, Map<_Key, int>>{};
    final schemes = <int, int>{};
    var tier = 1;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final plain = line.replaceAll(_date, ' ');
      final amounts = _amount.allMatches(plain).toList();
      // A section heading: "Tier II Account", "Transaction Details - Tier I".
      if (amounts.isEmpty) {
        final t = _tier.firstMatch(line);
        if (t != null) tier = _tierOf(grp(t, 1));
      }
      final found = scanLabels(plain, _labels);
      if (found.isNotEmpty) {
        final next =
            i + 1 < lines.length ? lines[i + 1].replaceAll(_date, ' ') : '';
        final below = scanLabels(next, _labels).isEmpty
            ? _amount.allMatches(next).map((m) => grp(m, 1)).toList()
            : <String>[];
        final into = summary.putIfAbsent(tier, () => {});
        for (var idx = 0; idx < found.length; idx++) {
          final hit = found[idx];
          if (hit.key == _Key.ret) continue;
          final end =
              idx + 1 < found.length ? found[idx + 1].first : plain.length;
          final sm = _amount.firstMatch(plain.substring(hit.last + 1, end));
          var raw = sm == null ? null : grp(sm, 1);
          if (raw == null) {
            if (below.isEmpty) continue;
            raw = below.removeAt(0);
          }
          final v = Money.parse(raw)?.minor ?? 0;
          into.putIfAbsent(hit.key, () => v);
        }
        continue;
      }

      // Scheme-wise rows: "SBI PENSION FUND SCHEME E - TIER I 4,567.1234
      // 45.6789 2,08,623.45".
      if (_schemeRow.hasMatch(line)) {
        final nums = <double>[
          for (final m in _number.allMatches(plain))
            if (parseDouble(m.group(0)!.replaceAll(',', '')) case final d?) d,
        ];
        if (nums.length < 2) continue;
        final tiers = _tier.allMatches(line).toList();
        final rowTier = tiers.isEmpty ? tier : _tierOf(grp(tiers.last, 1));
        final value = _consistentValue(nums) ?? nums.last;
        if (value > 0) {
          schemes[rowTier] = (schemes[rowTier] ?? 0) + paise(value);
        }
      }
    }
    final tiers = {...summary.keys, ...schemes.keys}.toList()..sort();
    final out = <HoldingSnapshot>[];
    for (final t in tiers) {
      final s = summary[t] ?? const <_Key, int>{};
      final sv = s[_Key.value];
      final value = sv != null && sv > 0 ? sv : schemes[t];
      if (value == null || value <= 0) continue;
      final gain = s[_Key.gain];
      int? invested;
      final c = s[_Key.contribution];
      if (c != null && c > 0) {
        final x = c - (s[_Key.withdrawal] ?? 0);
        if (x > 0) invested = x;
      }
      if (invested == null && gain != null) {
        final x = value - gain;
        if (x > 0) invested = x;
      }
      out.add(
        HoldingSnapshot(
          kind: HoldingKind.nps,
          name: InvestmentParser.npsName(last4, t),
          identifier: InvestmentParser.npsIdentifier(last4, t),
          units: null,
          valueMinor: value,
          investedMinor: invested,
          asOf: asOf,
        ),
      );
    }
    return out;
  }

  /// The value in `<units> <NAV> <value>`: the last number that equals the two
  /// before it multiplied.
  static double? _consistentValue(List<double> nums) {
    for (var k = nums.length - 1; k >= 2; k--) {
      final v = nums[k];
      final tol = v * 0.01 > 1.0 ? v * 0.01 : 1.0;
      if ((nums[k - 2] * nums[k - 1] - v).abs() <= tol) return v;
    }
    return null;
  }

  static int _tierOf(String s) => s.toLowerCase() == 'ii' || s == '2' ? 2 : 1;
}

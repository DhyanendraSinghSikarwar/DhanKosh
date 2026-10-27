import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/maturity_items.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';

/// One bar segment or donut slice (paise).
class ChartShare {
  /// Creates a share.
  const ChartShare(this.label, this.amountMinor, {this.assetClass});

  final String label;
  final int amountMinor;

  /// Set on class slices; drives the class filter.
  final AssetClass? assetClass;
}

/// Positive asset parts grouped by label, largest first; beyond [top] the
/// rest is one Others share (FR-16-06, B7).
List<ChartShare> splitByAccount(List<WorthPart> parts, {int top = 6}) {
  final byLabel = <String, int>{};
  for (final p in parts) {
    if (p.liability || p.amountMinor <= 0) continue;
    byLabel.update(
      p.label,
      (v) => v + p.amountMinor,
      ifAbsent: () => p.amountMinor,
    );
  }
  final sorted = byLabel.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final out = [for (final e in sorted.take(top)) ChartShare(e.key, e.value)];
  final rest = sorted.skip(top).fold<int>(0, (s, e) => s + e.value);
  if (rest > 0) out.add(ChartShare('Others', rest));
  return out;
}

/// Liability parts, largest first (FR-16-06).
List<ChartShare> liabilityShares(List<WorthPart> parts) => [
      for (final p in parts)
        if (p.liability && p.amountMinor > 0)
          ChartShare(p.label, p.amountMinor),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

/// Allocation slices: by class, or by holding inside [only] (B8).
/// [byClass] is the class map of the summary, cash included.
List<ChartShare> allocationShares(
  Map<AssetClass, int> byClass,
  List<Holding> holdings, {
  AssetClass? only,
}) {
  if (only == null) {
    return [
      for (final e in byClass.entries)
        if (e.value > 0) ChartShare(e.key.label, e.value, assetClass: e.key),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
  }
  if (only == AssetClass.cash) {
    final v = byClass[AssetClass.cash] ?? 0;
    return v > 0 ? [ChartShare('Cash', v, assetClass: only)] : const [];
  }
  return [
    for (final h in holdings)
      if (h.assetClass == only && (h.valueMinor ?? 0) > 0)
        ChartShare(h.name, h.valueMinor!, assetClass: only),
  ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
}

/// Previous then current value of [h] for a sparkline (B13); empty without a
/// previous figure.
List<int> holdingSpark(Holding h) {
  final p = h.previousValueMinor;
  final v = h.valueMinor;
  return p == null || v == null ? const [] : [p, v];
}

/// Maturities of the next 12 months grouped by calendar month, in date
/// order (C10 maturity calendar). Key is `Mon yyyy`.
Map<String, List<MaturityItem>> maturityByMonth(List<MaturityItem> items) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final sorted = [...items]..sort((a, b) => a.day.compareTo(b.day));
  final out = <String, List<MaturityItem>>{};
  for (final i in sorted) {
    final d = DateTime.utc(1970).add(Duration(days: i.day));
    out.putIfAbsent('${m[d.month - 1]} ${d.year}', () => []).add(i);
  }
  return out;
}

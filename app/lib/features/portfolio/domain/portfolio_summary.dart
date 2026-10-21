import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';

/// Value, cost and gain of the holdings (FR-16-02).
class PortfolioSummary {
  /// Creates a summary.
  const PortfolioSummary({
    required this.valueMinor,
    required this.investedMinor,
    required this.gainMinor,
    required this.returnPct,
    required this.byClass,
  });

  /// Value of all holdings.
  final int valueMinor;

  /// Invested over holdings with a cost only.
  final int investedMinor;

  /// Gain over holdings with a cost only.
  final int gainMinor;
  final double? returnPct;
  final Map<AssetClass, int> byClass;
}

/// Summary of [holdings]; gain and return cover holdings with a purchase
/// cost only (FR-16-02). [cashMinor] adds liquid cash to allocation.
PortfolioSummary summarisePortfolio(
  List<Holding> holdings, {
  int cashMinor = 0,
}) {
  var value = 0;
  var invested = 0;
  var gain = 0;
  final byClass = <AssetClass, int>{};
  for (final h in holdings) {
    final v = h.valueMinor ?? 0;
    if (v <= 0) continue;
    value += v;
    byClass.update(h.assetClass, (x) => x + v, ifAbsent: () => v);
    final g = h.gainMinor;
    if (g != null) {
      invested += h.investedMinor!;
      gain += g;
    }
  }
  if (cashMinor > 0) byClass[AssetClass.cash] = cashMinor;
  return PortfolioSummary(
    valueMinor: value,
    investedMinor: invested,
    gainMinor: gain,
    returnPct: invested > 0 ? gain / invested * 100 : null,
    byClass: byClass,
  );
}

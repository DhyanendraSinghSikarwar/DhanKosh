import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';

/// Class a holding is shown under on the Portfolio tab (FR-16-41).
enum PortfolioClass {
  stocks('Stocks'),
  mutualFunds('Mutual funds'),
  nps('NPS'),
  epfo('EPFO'),
  sukanya('Sukanya Samriddhi'),
  ppf('PPF'),
  fixedDeposit('FD / RD'),
  gold('Gold'),
  other('Bonds & others');

  const PortfolioClass(this.label);

  /// UI label.
  final String label;
}

/// Display class of [kind].
PortfolioClass portfolioClassOf(HoldingKind kind) => switch (kind) {
      HoldingKind.stock || HoldingKind.etf => PortfolioClass.stocks,
      HoldingKind.mutualFund => PortfolioClass.mutualFunds,
      HoldingKind.nps => PortfolioClass.nps,
      HoldingKind.epf => PortfolioClass.epfo,
      HoldingKind.sukanya => PortfolioClass.sukanya,
      HoldingKind.ppf => PortfolioClass.ppf,
      HoldingKind.fd => PortfolioClass.fixedDeposit,
      HoldingKind.gold => PortfolioClass.gold,
      HoldingKind.bond || HoldingKind.other => PortfolioClass.other,
    };

/// Kind a new holding of [c] is saved as.
HoldingKind holdingKindOfClass(PortfolioClass c) => switch (c) {
      PortfolioClass.stocks => HoldingKind.stock,
      PortfolioClass.mutualFunds => HoldingKind.mutualFund,
      PortfolioClass.nps => HoldingKind.nps,
      PortfolioClass.epfo => HoldingKind.epf,
      PortfolioClass.sukanya => HoldingKind.sukanya,
      PortfolioClass.ppf => HoldingKind.ppf,
      PortfolioClass.fixedDeposit => HoldingKind.fd,
      PortfolioClass.gold => HoldingKind.gold,
      PortfolioClass.other => HoldingKind.other,
    };

/// Holdings of one class with totals (FR-16-41).
class ClassGroup {
  /// Creates a group.
  const ClassGroup(this.cls, this.items);

  final PortfolioClass cls;
  final List<Holding> items;

  /// Value of the group.
  int get valueMinor => items.fold(0, (a, h) => a + (h.valueMinor ?? 0));

  /// Gain over holdings with a cost only, as percent; null without cost.
  double? get returnPct {
    var inv = 0;
    var gain = 0;
    for (final h in items) {
      final g = h.gainMinor;
      if (g != null) {
        inv += h.investedMinor!;
        gain += g;
      }
    }
    return inv > 0 ? gain / inv * 100 : null;
  }
}

/// Non-empty class groups in class order.
List<ClassGroup> groupByClass(List<Holding> holdings) => [
      for (final c in PortfolioClass.values)
        if (holdings.any((h) => portfolioClassOf(h.kind) == c))
          ClassGroup(
            c,
            holdings.where((h) => portfolioClassOf(h.kind) == c).toList(),
          ),
    ];

const _newsTerms = <PortfolioClass, List<String>>{
  PortfolioClass.stocks: ['stock', 'sensex', 'nifty', 'shares'],
  PortfolioClass.mutualFunds: ['mutual fund', 'sip', 'amfi'],
  PortfolioClass.nps: ['nps', 'pension'],
  PortfolioClass.epfo: ['epfo', 'epf', 'provident fund'],
  PortfolioClass.sukanya: ['sukanya', 'small savings'],
  PortfolioClass.ppf: ['ppf', 'small savings'],
  PortfolioClass.fixedDeposit: ['fixed deposit', 'fd rate', 'deposit rate'],
  PortfolioClass.gold: ['gold'],
};

/// Class label a headline relates to, null when it names none (the tag on a
/// news row).
String? headlineClassLabel(String title) {
  final t = title.toLowerCase();
  for (final e in _newsTerms.entries) {
    if (e.value.any(t.contains)) return e.key.label;
  }
  return null;
}

/// Lower-case words that mark a headline as relevant to [holdings]: class
/// terms plus the first word of each holding name (FR-31-40).
Set<String> holdingNewsKeywords(List<Holding> holdings) {
  final out = <String>{};
  for (final h in holdings) {
    out.addAll(_newsTerms[portfolioClassOf(h.kind)] ?? const []);
    final first = h.name.trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (first.length >= 4) out.add(first);
  }
  return out;
}

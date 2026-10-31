import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_class.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_class_style.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Allocation donut with legend rows by asset class (FR-16-02, FR-16-41).
/// Tapping a slice or row focuses that class; tapping it again clears.
class AllocationCard extends StatelessWidget {
  /// Creates the card.
  const AllocationCard({
    required this.groups,
    required this.focus,
    required this.onFocus,
    required this.money,
    required this.asOfLabel,
    this.investedMinor = 0,
    this.gainMinor = 0,
    super.key,
  });

  /// Non-empty class groups.
  final List<ClassGroup> groups;

  /// Focused class, null for all.
  final PortfolioClass? focus;

  /// Called with the class to focus, null to clear.
  final ValueChanged<PortfolioClass?> onFocus;
  final String Function(int) money;

  /// `as of ...` text, empty when unknown.
  final String asOfLabel;
  final int investedMinor;
  final int gainMinor;

  void _tap(PortfolioClass c) => onFocus(focus == c ? null : c);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = [
      for (final g in groups)
        if (g.valueMinor > 0) g,
    ]..sort((a, b) => b.valueMinor.compareTo(a.valueMinor));
    final total = shown.fold<int>(0, (a, g) => a + g.valueMinor);
    return AppCard(
      key: const Key('allocation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Allocation', style: theme.textTheme.titleSmall),
          if (asOfLabel.isNotEmpty)
            Text(
              asOfLabel,
              key: const Key('allocation-as-of'),
              style: theme.textTheme.bodySmall,
            ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    key: const Key('alloc-donut'),
                    PieChartData(
                      centerSpaceRadius: 54,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (e, r) {
                          if (e is! FlTapUpEvent) return;
                          final i = r?.touchedSection?.touchedSectionIndex;
                          if (i != null && i >= 0 && i < shown.length) {
                            _tap(shown[i].cls);
                          }
                        },
                      ),
                      sections: [
                        for (final g in shown)
                          PieChartSectionData(
                            value: g.valueMinor / 100,
                            color: portfolioClassColor(g.cls).withValues(
                              alpha: focus == null || focus == g.cls ? 1 : 0.3,
                            ),
                            radius: focus == g.cls ? 34 : 28,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          focus?.label ?? 'Invested',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          money(
                            focus == null
                                ? total
                                : shown
                                    .where((g) => g.cls == focus)
                                    .fold<int>(0, (a, g) => a + g.valueMinor),
                          ),
                          key: const Key('alloc-center'),
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final g in shown)
              InkWell(
                key: Key('alloc-row-${g.cls.name}'),
                onTap: () => _tap(g.cls),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: portfolioClassColor(g.cls),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          g.cls.label,
                          style: focus == g.cls
                              ? const TextStyle(fontWeight: FontWeight.w700)
                              : null,
                        ),
                      ),
                      Text(
                        money(g.valueMinor),
                        style: theme.textTheme.bodySmall,
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(g.valueMinor * 100 / total).round()}%',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (investedMinor > 0) ...[
            const Divider(),
            Text(
              'Invested ${money(investedMinor)}  ·  Gain '
              '${gainMinor < 0 ? '-' : '+'}${money(gainMinor.abs())}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

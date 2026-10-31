import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_class.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_class_style.dart';
import 'package:hisaab/features/portfolio/presentation/section_info_label.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Allocation donut, class bar and legend rows by asset class (FR-16-02,
/// FR-16-41). Tapping a slice or row focuses that class; tapping it again
/// clears.
class AllocationCard extends StatelessWidget {
  /// Creates the card.
  const AllocationCard({
    required this.groups,
    required this.focus,
    required this.onFocus,
    required this.money,
    required this.compact,
    required this.asOfLabel,
    this.investedMinor = 0,
    this.gainMinor = 0,
    super.key,
  });

  /// Non-empty class groups, in class order.
  final List<ClassGroup> groups;

  /// Focused class, null for all.
  final PortfolioClass? focus;

  /// Called with the class to focus, null to clear.
  final ValueChanged<PortfolioClass?> onFocus;
  final String Function(int) money;

  /// Short money text for the donut centre (`19.6L`).
  final String Function(int) compact;

  /// `as of ...` text, empty when unknown.
  final String asOfLabel;
  final int investedMinor;
  final int gainMinor;

  void _tap(PortfolioClass c) => onFocus(focus == c ? null : c);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final shown = [
      for (final g in groups)
        if (g.valueMinor > 0) g,
    ];
    final total = shown.fold<int>(0, (a, g) => a + g.valueMinor);
    final focused = shown.where((g) => g.cls == focus).toList();
    return AppCard(
      key: const Key('allocation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionInfoLabel(
            'Allocation',
            tip: 'Share of investments by asset class. Tap a slice or a row '
                'to open that class.',
          ),
          if (asOfLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                asOfLabel,
                key: const Key('allocation-as-of'),
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        key: const Key('alloc-donut'),
                        PieChartData(
                          centerSpaceRadius: 44,
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
                                  alpha:
                                      focus == null || focus == g.cls ? 1 : 0.3,
                                ),
                                radius: focus == g.cls ? 26 : 20,
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
                              focused.isEmpty ? 'Invested' : focus!.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                            Text(
                              focused.isEmpty
                                  ? compact(total)
                                  : compact(focused.first.valueMinor),
                              key: const Key('alloc-center'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        key: const Key('alloc-bar'),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            for (final g in shown)
                              Expanded(
                                flex: (g.valueMinor * 1000 ~/ total)
                                    .clamp(1, 1000),
                                child: Container(
                                  height: 12,
                                  color: portfolioClassColor(g.cls),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${shown.length} asset classes',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final g in shown)
              InkWell(
                key: Key('alloc-row-${g.cls.name}'),
                onTap: () => _tap(g.cls),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
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
                        style: TextStyle(fontSize: 12, color: muted),
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

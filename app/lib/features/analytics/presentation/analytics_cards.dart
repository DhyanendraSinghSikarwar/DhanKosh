import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Formats paise for display.
typedef MoneyText = String Function(int minor);

const _palette = [
  Color(0xFF2E7D6B),
  Color(0xFF3F6FB5),
  Color(0xFFC77D2B),
  Color(0xFF8A5BB0),
  Color(0xFFC0504D),
  Color(0xFF4C9AA8),
  Color(0xFF9AA03A),
  Color(0xFF7A7F87),
];

Widget _titled(BuildContext context, String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );

Widget _row(BuildContext context, String label, String value, {Color? color}) {
  final t = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: t.bodyMedium)),
        Text(value, style: t.bodyMedium?.copyWith(color: color)),
      ],
    ),
  );
}

/// Up to 5 insight cards (FR-18-17).
class InsightsCard extends StatelessWidget {
  /// Creates the card.
  const InsightsCard({required this.insights, super.key});

  /// Insights to show.
  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return _titled(
      context,
      'Insights',
      Column(
        key: const Key('analytics-insights'),
        children: [
          for (final i in insights)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                switch (i.tone) {
                  Tone.good => Icons.check_circle_outline,
                  Tone.warn => Icons.warning_amber_outlined,
                  Tone.info => Icons.info_outline,
                },
                color: switch (i.tone) {
                  Tone.good => scheme.primary,
                  Tone.warn => scheme.error,
                  Tone.info => scheme.outline,
                },
              ),
              title: Text(i.title),
              subtitle: Text(i.detail),
            ),
        ],
      ),
    );
  }
}

/// Spent, income, saved and per-day (FR-18-03).
class KpiRow extends StatelessWidget {
  /// Creates the row.
  const KpiRow({
    required this.data,
    required this.money,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final over = data.savedOrOver < 0;
    return _titled(
      context,
      'Summary',
      Column(
        children: [
          _row(context, 'Spent', money(data.spent)),
          _row(context, 'Income', money(data.income)),
          _row(
            context,
            over ? 'Overspent' : 'Saved',
            money(data.savedOrOver.abs()),
            color: over ? Theme.of(context).colorScheme.error : null,
          ),
          _row(context, 'Per day', money(data.perDay)),
        ],
      ),
    );
  }
}

/// Category donut with legend (FR-18-03).
class CategoryDonutCard extends StatelessWidget {
  /// Creates the card.
  const CategoryDonutCard({
    required this.data,
    required this.money,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final cats = data.categories;
    if (cats.isEmpty) {
      return _titled(context, 'By category', const Text('No spending'));
    }
    final top = cats.take(7).toList();
    final rest = cats.skip(7).fold(0, (a, e) => a + e.$2);
    final slices = [
      for (final (i, e) in top.indexed) (e.$1.label, e.$2, _palette[i]),
      if (rest > 0) ('Other', rest, _palette[7]),
    ];
    return _titled(
      context,
      'By category',
      Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              key: const Key('analytics-donut'),
              PieChartData(
                centerSpaceRadius: 54,
                sectionsSpace: 2,
                sections: [
                  for (final s in slices)
                    PieChartSectionData(
                      value: s.$2.toDouble(),
                      color: s.$3,
                      radius: 28,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final s in slices)
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: s.$3, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: _row(context, s.$1, money(s.$2))),
              ],
            ),
        ],
      ),
    );
  }
}

/// 12-month spending trend (FR-18-05).
class MonthlyTrendCard extends StatelessWidget {
  /// Creates the card.
  const MonthlyTrendCard({
    required this.data,
    required this.money,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final m = data.monthly;
    final scheme = Theme.of(context).colorScheme;
    final maxV = m.fold(0, (a, e) => math.max(a, e.spent));
    final avg = LedgerMath.averageExcludingLast(m);
    return _titled(
      context,
      'Monthly trend',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            child: BarChart(
              key: const Key('analytics-trend'),
              BarChartData(
                maxY: maxV == 0 ? 1 : maxV * 1.1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) => Text(
                        AnalyticsMath.monthLabel(m[v.toInt()].month)
                            .substring(0, 1),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (final (i, e) in m.indexed)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: e.spent.toDouble(),
                          width: 12,
                          borderRadius: BorderRadius.circular(3),
                          color: i == m.length - 1
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          _row(context, '11-month average', money(avg)),
        ],
      ),
    );
  }
}

/// Weekday by time-of-day heatmap (FR-18-06).
class HeatmapCard extends StatelessWidget {
  /// Creates the card.
  const HeatmapCard({required this.heat, super.key});

  /// 7x8 grid, Monday first.
  final HeatGrid heat;

  @override
  Widget build(BuildContext context) {
    if (heat.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final maxV = heat.fold(0, (a, r) => math.max(a, r.fold(0, math.max)));
    final peak = LedgerMath.heatPeak(heat);
    return _titled(
      context,
      'When you spend',
      Column(
        key: const Key('analytics-heat'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var d = 0; d < 7; d++)
            Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    LedgerMath.dayLabels[d],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                for (var s = 0; s < 8; s++)
                  Expanded(
                    child: Container(
                      height: 20,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(
                          alpha:
                              maxV == 0 ? 0.06 : 0.06 + 0.9 * heat[d][s] / maxV,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          if (peak != null) ...[
            const SizedBox(height: 8),
            Text('Most on ${LedgerMath.peakText(peak)}'),
          ],
        ],
      ),
    );
  }
}

/// Top merchants (FR-18-07).
class TopMerchantsCard extends StatelessWidget {
  /// Creates the card.
  const TopMerchantsCard({
    required this.merchants,
    required this.money,
    super.key,
  });

  /// Merchants, largest first.
  final List<MerchantSpend> merchants;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) return const SizedBox.shrink();
    return _titled(
      context,
      'Top merchants',
      Column(
        children: [
          for (final m in merchants)
            _row(context, '${m.name} (${m.count})', money(m.total)),
        ],
      ),
    );
  }
}

/// Budget progress per category (FR-18-08).
class BudgetsCard extends StatelessWidget {
  /// Creates the card.
  const BudgetsCard({
    required this.data,
    required this.money,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final lines = data.budgets?.lines ?? const [];
    if (lines.isEmpty) return const SizedBox.shrink();
    return _titled(
      context,
      'Budgets',
      Column(
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  _row(
                    context,
                    l.category.label,
                    '${money(l.spentMinor)} / ${money(l.limitMinor)}',
                  ),
                  LinearProgressIndicator(value: l.fraction.clamp(0, 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Where income went, as bars (FR-18-09; Sankey deferred).
class IncomeFlowCard extends StatelessWidget {
  /// Creates the card.
  const IncomeFlowCard({
    required this.data,
    required this.money,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final s = AnalyticsMath.sankey(data);
    final total = math.max(1, data.income);
    Widget bar(String label, int v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            children: [
              _row(context, label, money(v)),
              LinearProgressIndicator(value: (v / total).clamp(0, 1)),
            ],
          ),
        );
    return _titled(
      context,
      'Where your income went',
      Column(
        key: const Key('analytics-flow'),
        children: [
          for (final n in s.inputs) _row(context, n.label, money(n.value)),
          const Divider(),
          for (final n in s.outputs) bar(n.label, n.value),
          bar(s.isShortfall ? 'Shortfall' : 'Left over', s.leftOver),
        ],
      ),
    );
  }
}

/// Savings rate (FR-18-11).
class SavingsRateCard extends StatelessWidget {
  /// Creates the card.
  const SavingsRateCard({required this.data, super.key});

  /// Period data.
  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final s = AnalyticsMath.savingsSummary(data.savingsRates);
    if (s == null) return const SizedBox.shrink();
    return _titled(
      context,
      'Savings rate',
      Column(
        children: [
          _row(
            context,
            AnalyticsMath.monthLabel(s.latestMonth),
            '${s.latestPercent}%',
          ),
          _row(
            context,
            'Average of ${s.months} months',
            '${s.averagePercent}%',
          ),
        ],
      ),
    );
  }
}

/// 30-day cash projection (FR-18-15).
class CashProjectionCard extends StatelessWidget {
  /// Creates the card.
  const CashProjectionCard({
    required this.data,
    required this.money,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final c = data.cash;
    if (c == null) return const SizedBox.shrink();
    return _titled(
      context,
      'Next 30 days',
      Column(
        key: const Key('analytics-cash'),
        children: [
          _line(context, c.series.map((e) => e.toDouble()).toList()),
          _row(context, 'Today', money(c.start)),
          _row(context, 'In 30 days', money(c.end)),
          if (c.shortfall)
            Text(
              'Cash may run short on ${AnalyticsMath.shortDay(c.lowestOn)}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

Widget _line(BuildContext context, List<double> ys) {
  final scheme = Theme.of(context).colorScheme;
  return SizedBox(
    height: 120,
    child: LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final (i, y) in ys.indexed) FlSpot(i.toDouble(), y)],
            color: scheme.primary,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    ),
  );
}

/// Month-end forecast range and verdict (FR-18-13, FR-18-14).
class ForecastCard extends StatelessWidget {
  /// Creates the card.
  const ForecastCard({
    required this.data,
    required this.money,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final f = data.forecast;
    if (f == null) {
      return _titled(
        context,
        'Forecast',
        const Text('Forecast is for the current month.'),
      );
    }
    final v = f.verdict(data.budget);
    final text = switch (v.kind) {
      ForecastVerdictKind.noBudget => 'No budget set',
      ForecastVerdictKind.within => 'Within budget of ${money(v.budget)}',
      ForecastVerdictKind.over => 'Over budget by ${money(v.overBy)}',
    };
    return _titled(
      context,
      'Month-end forecast',
      Column(
        key: const Key('analytics-forecast'),
        children: [
          _line(context, f.expected.map((e) => e.toDouble()).toList()),
          _row(context, 'Likely', money(f.likely)),
          _row(context, 'Range', '${money(f.lowEnd)} – ${money(f.highEnd)}'),
          _row(context, 'Bills left', money(f.billsLeft)),
          Text(text),
        ],
      ),
    );
  }
}

/// Change versus the previous period by category (FR-18-16).
class CompareCard extends StatelessWidget {
  /// Creates the card.
  const CompareCard({
    required this.data,
    required this.money,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _titled(
      context,
      'Versus ${data.previousLabel}',
      Column(
        key: const Key('analytics-compare'),
        children: [
          _row(context, 'This period', money(data.spent)),
          _row(context, 'Previous', money(data.previousSpent)),
          const Divider(),
          for (final c in data.changes.take(10))
            _row(
              context,
              c.category.label,
              '${c.percent > 0 ? '+' : ''}${c.percent}%',
              color: c.percent > 0 ? scheme.error : scheme.primary,
            ),
        ],
      ),
    );
  }
}

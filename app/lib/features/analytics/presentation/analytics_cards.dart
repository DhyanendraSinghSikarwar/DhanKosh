import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Formats paise for display.
typedef MoneyText = String Function(int minor);

/// Series colours.
const chartPalette = [
  Color(0xFF2E7D6B),
  Color(0xFF3F6FB5),
  Color(0xFFC77D2B),
  Color(0xFF8A5BB0),
  Color(0xFFC0504D),
  Color(0xFF4C9AA8),
  Color(0xFF9AA03A),
  Color(0xFF7A7F87),
];

/// Titled card shell.
Widget titledCard(BuildContext context, String title, Widget child) => Padding(
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

/// Label and value row.
Widget labelRow(
  BuildContext context,
  String label,
  String value, {
  Color? color,
  bool bold = false,
  Key? key,
}) {
  final t = Theme.of(context).textTheme;
  return Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: bold
                ? t.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
                : t.bodyMedium,
          ),
        ),
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
    return titledCard(
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
    this.spent,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  /// Cash-basis headline spend from `SpendCalc.totals` (ADR-0011); the
  /// period's own figure when null.
  final int? spent;

  @override
  Widget build(BuildContext context) {
    final headline = spent ?? data.spent;
    final saved = spent == null
        ? data.savedOrOver
        : data.income - headline - data.invested;
    final over = saved < 0;
    return titledCard(
      context,
      'Summary',
      Column(
        children: [
          labelRow(context, 'Spent', money(headline)),
          labelRow(context, 'Income', money(data.income)),
          labelRow(
            context,
            over ? 'Overspent' : 'Saved',
            money(saved.abs()),
            color: over ? Theme.of(context).colorScheme.error : null,
          ),
          labelRow(context, 'Per day', money(data.perDay)),
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
    return titledCard(
      context,
      'Top merchants',
      Column(
        children: [
          for (final m in merchants)
            labelRow(context, '${m.name} (${m.count})', money(m.total)),
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
    return titledCard(
      context,
      'Budgets',
      Column(
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  labelRow(
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
    return titledCard(
      context,
      'Next 30 days',
      Column(
        key: const Key('analytics-cash'),
        children: [
          _line(context, c.series.map((e) => e.toDouble()).toList()),
          labelRow(context, 'Today', money(c.start)),
          labelRow(context, 'In 30 days', money(c.end)),
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

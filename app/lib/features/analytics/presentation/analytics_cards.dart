import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/shared/widgets/charts/chart_card.dart';
import 'package:hisaab/shared/widgets/charts/chart_style.dart';
import 'package:hisaab/shared/widgets/charts/line_chart_view.dart';

/// Formats paise for display.
typedef MoneyText = String Function(int minor);

/// Series colours (mint, blue, amber, violet, red, teal, olive, grey).
const List<Color> chartPalette = ChartColors.palette;

/// Titled card shell.
Widget titledCard(BuildContext context, String title, Widget child) =>
    ChartCard(label: title, child: child);

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
        Text(
          value,
          style:
              t.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 10),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: switch (i.tone) {
                        Tone.good => ChartColors.mint,
                        Tone.warn => ChartColors.red,
                        Tone.info => scheme.onSurfaceVariant,
                      },
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.title),
                        Text(
                          i.detail,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
            color: over ? ChartColors.red : null,
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
    final scheme = Theme.of(context).colorScheme;
    return titledCard(
      context,
      'Top merchants',
      Column(
        children: [
          for (final m in merchants)
            Padding(
              key: Key('merchant-${m.name}'),
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: m.name,
                        children: [
                          if (m.count > 1)
                            TextSpan(
                              text: '  ×${m.count}',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    money(m.total),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
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
    final style = ChartStyle.of(context);
    return titledCard(
      context,
      'Budgets',
      Column(
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(l.category.label)),
                      Text(
                        '${money(l.spentMinor)} / ${money(l.limitMinor)}',
                        style: TextStyle(color: style.label, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: l.fraction.clamp(0, 1),
                      color: l.fraction >= 1
                          ? ChartColors.red
                          : l.fraction >= 0.8
                              ? ChartColors.amber
                              : ChartColors.mint,
                      backgroundColor: style.track,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 30-day cash projection line (FR-18-15).
class CashProjectionCard extends StatelessWidget {
  /// Creates the card.
  const CashProjectionCard({
    required this.data,
    required this.money,
    this.masked = false,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  /// Axis labels hidden.
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final c = data.cash;
    final scheme = Theme.of(context).colorScheme;
    if (c == null) {
      return titledCard(
        context,
        'Cash balance, next 30 days',
        Text(
          'No bank balance known yet. Balances are read from bank SMS, or you '
          'can set one on an account.',
          key: const Key('analytics-cash-empty'),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      );
    }
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    return titledCard(
      context,
      'Cash balance, next 30 days',
      Column(
        key: const Key('analytics-cash'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LineChartView(
            height: 130,
            minY: c.lowest < 0 ? -niceMax(-c.lowest.toDouble()) : 0,
            series: [
              LineSeries(
                [for (final v in c.series) v.toDouble()],
                ChartColors.blue,
                fill: true,
                endDot: true,
              ),
            ],
            yLabel: (v) => axisLabel(v, masked: masked),
            xLabels: [
              (0, 'Today'),
              (c.series.length ~/ 2, '+15d'),
              (c.series.length - 1, '+30d'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lowest ${money(c.lowest)} on ${AnalyticsMath.shortDay(c.lowestOn)}.',
            style: muted,
          ),
          Text(
            'Today ${money(c.start)} · In 30 days ${money(c.end)}',
            style: muted,
          ),
          if (c.shortfall)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Cash may run short on ${AnalyticsMath.shortDay(c.lowestOn)}.',
                key: const Key('analytics-cash-short'),
                style: const TextStyle(color: ChartColors.red, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

/// Muted caption under a chart.
class ChartCaption extends StatelessWidget {
  /// Creates the caption.
  const ChartCaption(this.text, {super.key});

  /// Caption text.
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      );
}

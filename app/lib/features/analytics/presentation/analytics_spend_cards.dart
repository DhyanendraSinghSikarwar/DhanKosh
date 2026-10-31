import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/analytics/presentation/analytics_card.dart';
import 'package:hisaab/features/analytics/presentation/analytics_cards.dart';
import 'package:hisaab/features/analytics/presentation/charts/bars_chart.dart';
import 'package:hisaab/features/analytics/presentation/charts/chart_style.dart';
import 'package:hisaab/features/analytics/presentation/charts/line_chart_view.dart';
import 'package:hisaab/features/analytics/presentation/pill_segment.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

/// Total spent: big figure, transaction count, daily average and the
/// month-end forecast (FR-18-03).
class TotalSpentCard extends StatelessWidget {
  /// Creates the card.
  const TotalSpentCard({
    required this.spent,
    required this.txCount,
    required this.perDay,
    required this.money,
    required this.tip,
    this.forecast,
    this.forecastDay,
    super.key,
  });

  /// Cash-basis headline spend in paise.
  final int spent;

  /// Number of spend rows.
  final int txCount;

  /// Average per day in paise.
  final int perDay;

  /// Amount formatter.
  final MoneyText money;

  /// Text of the (i) note.
  final String tip;

  /// Expected month-end spend, current month only.
  final int? forecast;

  /// Last day of the month, for the forecast label.
  final DateTime? forecastDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnalyticsCard(
      label: 'Total spent',
      tip: tip,
      tipKey: const Key('analytics-basis-note'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(spent),
                    key: const Key('analytics-total'),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$txCount txns',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Average'),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      text: money(perDay),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: ' /day',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (forecast != null && forecastDay != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SectionLabel(
                      'Forecast ${AnalyticsMath.shortDay(forecastDay!)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(forecast!),
                      key: const Key('analytics-total-forecast'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Daily spend as a cumulative line or per-day bars (FR-18-03).
class DailySpendCard extends StatefulWidget {
  /// Creates the card.
  const DailySpendCard({
    required this.txs,
    required this.from,
    required this.to,
    this.upto,
    this.masked = false,
    super.key,
  });

  /// Spend rows of the period (already cross-filtered).
  final List<LedgerTx> txs;

  /// First day of the period.
  final DateTime from;

  /// Last day of the period.
  final DateTime to;

  /// Last day with data (today in a running period); the whole period when
  /// null.
  final DateTime? upto;

  /// Axis labels hidden.
  final bool masked;

  @override
  State<DailySpendCard> createState() => _DailySpendCardState();
}

class _DailySpendCardState extends State<DailySpendCard> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final days = widget.to.difference(widget.from).inDays + 1;
    final byDay = LedgerMath.daily(widget.txs);
    final last = widget.upto == null
        ? days - 1
        : (widget.upto!.difference(widget.from).inDays).clamp(0, days - 1);
    final perDay = [
      for (var i = 0; i < days; i++)
        byDay[widget.from.add(Duration(days: i))] ?? 0,
    ];
    var run = 0;
    final cumulative = [
      for (var i = 0; i <= last; i++) run += perDay[i],
    ];
    final i1 = ((days - 1) / 3).round();
    final i2 = ((days - 1) * 2 / 3).round();
    final xLabels = <(int, String)>[
      (0, AnalyticsMath.shortDay(widget.from)),
      if (days > 6) (i1, '${widget.from.add(Duration(days: i1)).day}'),
      if (days > 6) (i2, '${widget.from.add(Duration(days: i2)).day}'),
      (days - 1, '${widget.to.day}'),
    ];
    return AnalyticsCard(
      label: 'Daily spend',
      trailing: PillSegment(
        options: const ['Line', 'Bars'],
        selected: _mode,
        onChanged: (i) => setState(() => _mode = i),
      ),
      child: _mode == 0
          ? LineChartView(
              key: const Key('analytics-daily-line'),
              series: [
                LineSeries(
                  [for (final v in cumulative) v.toDouble()],
                  ChartColors.mint,
                  fill: true,
                  endDot: true,
                ),
              ],
              pointCount: days,
              yLabel: (v) => axisLabel(v, masked: widget.masked),
              xLabels: xLabels,
            )
          : BarsChart(
              key: const Key('analytics-daily-bars'),
              values: perDay,
              color: ChartColors.mint,
              xLabels: xLabels,
              masked: widget.masked,
            ),
    );
  }
}

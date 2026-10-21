import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';

/// Net worth line over [points] (FR-16-05). Needs two or more points.
class NetWorthChart extends StatelessWidget {
  /// Creates the chart.
  const NetWorthChart({required this.points, super.key});

  /// Points inside the chosen range, oldest first.
  final List<WorthPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.length < 2) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'History builds up day by day',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final first = points.first.day;
    return Semantics(
      label: 'Net worth history chart',
      child: SizedBox(
        height: 140,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final p in points)
                    FlSpot((p.day - first).toDouble(), p.netMinor / 100),
                ],
                color: scheme.primary,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: scheme.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

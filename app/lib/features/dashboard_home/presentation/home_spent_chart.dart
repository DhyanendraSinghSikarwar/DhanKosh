import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Running spend line, this month against last month (FR-17-06, B4).
/// Series are cumulative paise per day.
class HomeSpentChart extends StatelessWidget {
  /// Creates the chart.
  const HomeSpentChart({
    required this.current,
    required this.previous,
    super.key,
  });

  /// This month, day 1 first.
  final List<int> current;

  /// Last month, day 1 first.
  final List<int> previous;

  List<FlSpot> _spots(List<int> v) => [
        for (final (i, x) in v.indexed) FlSpot(i + 1.0, x / 100),
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Spend this month against last month',
      child: SizedBox(
        key: const Key('home_spent_chart'),
        height: 110,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            minY: 0,
            lineBarsData: [
              if (previous.length > 1)
                LineChartBarData(
                  spots: _spots(previous),
                  color: scheme.outline,
                  barWidth: 1.5,
                  dashArray: [4, 4],
                  dotData: const FlDotData(show: false),
                ),
              if (current.isNotEmpty)
                LineChartBarData(
                  spots: _spots(current),
                  color: scheme.primary,
                  barWidth: 2.5,
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

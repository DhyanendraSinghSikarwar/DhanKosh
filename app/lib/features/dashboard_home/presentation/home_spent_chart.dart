import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Running spend line, this month against last month (FR-17-06, B4):
/// dashed grid, compact y labels (0..max), x labels 1/10/20/31 and an end
/// dot. Series are cumulative paise per day.
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

  /// Compact axis label: 1.2L, 45K, 800.
  static String compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).round()}K';
    return v.round().toString();
  }

  /// Round-up axis maximum so the y labels are tidy.
  static double niceMax(double raw) {
    if (raw <= 0) return 3;
    final step = raw > 100000
        ? 30000.0
        : raw > 10000
            ? 3000.0
            : 300.0;
    return (raw * 1.08 / step).ceil() * step;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final days =
        current.length > previous.length ? current.length : previous.length;
    final peak =
        [...current, ...previous].fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = niceMax(peak / 100);
    final labelStyle = TextStyle(fontSize: 10, color: muted);
    final xs = {1, 10, 20, days};
    final lastCur = current.length;
    return Semantics(
      label: 'Spend this month against last month',
      child: SizedBox(
        key: const Key('home_spent_chart'),
        height: 130,
        child: LineChart(
          LineChartData(
            minX: 1,
            maxX: days < 2 ? 2 : days.toDouble(),
            minY: 0,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 3,
              getDrawingHorizontalLine: (_) => FlLine(
                color: scheme.outlineVariant,
                strokeWidth: 1,
                dashArray: [3, 4],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: maxY / 3,
                  getTitlesWidget: (v, m) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      compact(v),
                      textAlign: TextAlign.right,
                      style: labelStyle,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  interval: 1,
                  getTitlesWidget: (v, m) =>
                      xs.contains(v.round()) && v == v.roundToDouble()
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${v.round()}', style: labelStyle),
                            )
                          : const SizedBox.shrink(),
                ),
              ),
            ),
            lineBarsData: [
              if (previous.length > 1)
                LineChartBarData(
                  spots: _spots(previous),
                  color: muted,
                  barWidth: 1.5,
                  dashArray: [4, 4],
                  dotData: const FlDotData(show: false),
                ),
              if (current.isNotEmpty)
                LineChartBarData(
                  spots: _spots(current),
                  color: scheme.primary,
                  dotData: FlDotData(
                    checkToShowDot: (s, b) => s.x == lastCur.toDouble(),
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      color: scheme.primary,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: scheme.primary.withValues(alpha: 0.14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

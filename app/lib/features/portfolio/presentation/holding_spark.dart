import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Tiny previous-to-current value line of a holding (B13). Draws nothing
/// with fewer than two values.
class HoldingSpark extends StatelessWidget {
  /// Creates the sparkline over [values] (paise, oldest first).
  const HoldingSpark({required this.values, required this.color, super.key});

  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return SizedBox(
      width: 64,
      height: 28,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final (i, v) in values.indexed)
                  FlSpot(i.toDouble(), v / 100),
              ],
              color: color,
              barWidth: 1.5,
              isCurved: true,
              curveSmoothness: 0.2,
              dotData: FlDotData(
                checkToShowDot: (s, _) => s.x == values.length - 1,
                getDotPainter: (s, a, b, c) => FlDotCirclePainter(
                  radius: 2.5,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

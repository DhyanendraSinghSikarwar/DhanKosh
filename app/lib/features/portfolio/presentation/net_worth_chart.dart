import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/presentation/compact_money.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Net worth line over [points] with filled area, end dot and axis labels
/// (FR-16-05). Needs two or more points; [masked] hides the value axis.
class NetWorthChart extends StatelessWidget {
  /// Creates the chart.
  const NetWorthChart({required this.points, this.masked = false, super.key});

  /// Points inside the chosen range, oldest first.
  final List<WorthPoint> points;

  /// Hides the value axis labels.
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 10, color: scheme.onSurfaceVariant);
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
    final span = (points.last.day - first).clamp(1, 1 << 30).toDouble();
    final values = [for (final p in points) p.netMinor / 100];
    final hi = values.reduce((a, b) => a > b ? a : b);
    final lo = values.reduce((a, b) => a < b ? a : b);
    final minY = lo < 0 ? lo * 1.1 : 0.0;
    final maxY = hi <= minY ? minY + 1 : hi * 1.08;
    final step = (maxY - minY) / 3;
    String month(double x) {
      final d = DateTime.utc(1970).add(Duration(days: first + x.round()));
      return _months[d.month - 1];
    }

    return Semantics(
      label: 'Net worth history chart',
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            minX: 0,
            maxX: span,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) => FlLine(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
                strokeWidth: 0.6,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: !masked,
                  reservedSize: 34,
                  interval: step,
                  getTitlesWidget: (v, meta) => Text(
                    compactMoney((v * 100).round()),
                    style: muted,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  interval: span / 3,
                  getTitlesWidget: (v, meta) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(month(v), style: muted),
                  ),
                ),
              ),
            ),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final p in points)
                    FlSpot((p.day - first).toDouble(), p.netMinor / 100),
                ],
                color: scheme.primary,
                dotData: FlDotData(
                  checkToShowDot: (s, _) => s.x == span,
                  getDotPainter: (s, a, b, c) => FlDotCirclePainter(
                    radius: 4,
                    color: scheme.primary,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.primary.withValues(alpha: 0.28),
                      scheme.primary.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/presentation/charts/chart_style.dart';

/// One line of a [LineChartView].
class LineSeries {
  /// Creates a series.
  const LineSeries(
    this.values,
    this.color, {
    this.fill = false,
    this.dashed = false,
    this.width = 2,
    this.endDot = false,
  });

  /// Values in paise (or percent when the axis says so).
  final List<double> values;

  /// Stroke colour.
  final Color color;

  /// Soft area fill under the line.
  final bool fill;

  /// Dashed stroke.
  final bool dashed;

  /// Stroke width.
  final double width;

  /// Dot on the last point.
  final bool endDot;
}

/// Line chart in the mock's style: dashed grid, y labels, x labels, end dot.
class LineChartView extends StatelessWidget {
  /// Creates the chart.
  const LineChartView({
    required this.series,
    required this.yLabel,
    this.xLabels = const [],
    this.maxY,
    this.minY = 0,
    this.pointCount,
    this.height = 150,
    super.key,
  });

  /// Lines, all with the same number of points.
  final List<LineSeries> series;

  /// Label of an axis value.
  final String Function(double) yLabel;

  /// Labels as (point index, text).
  final List<(int, String)> xLabels;

  /// Axis maximum; derived from the data when null.
  final double? maxY;

  /// Axis minimum (below zero for savings rate).
  final double minY;

  /// Points the x axis spans; the longest series when null (a series may
  /// stop early, like spend up to today).
  final int? pointCount;

  /// Chart height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = ChartStyle.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(
            series, yLabel, xLabels, maxY, minY, pointCount, style),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.series, this.yLabel, this.xLabels, this.maxY, this.minY,
      this.pointCount, this.style);

  final List<LineSeries> series;
  final String Function(double) yLabel;
  final List<(int, String)> xLabels;
  final double? maxY;
  final double minY;
  final int? pointCount;
  final ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.values.isEmpty) return;
    final p = Plot(size);
    final n = pointCount ??
        series.fold<int>(
            0, (a, s) => s.values.length > a ? s.values.length : a);
    final all = [for (final s in series) ...s.values];
    final top = all.fold<double>(0, (a, v) => v > a ? v : a);
    final max = maxY ?? niceMax(top);
    paintGrid(canvas, p, max, style, label: yLabel, min: minY);
    for (final (i, t) in xLabels) {
      paintText(
        canvas,
        t,
        Offset(p.x(i, n), size.height - 6),
        color: style.label,
        align: TextAlign.center,
      );
    }
    for (final s in series) {
      final path = Path();
      for (final (i, v) in s.values.indexed) {
        final o = Offset(p.x(i, n), p.y(v.clamp(minY, max), max, minY));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      if (s.fill) {
        final area = Path.from(path)
          ..lineTo(p.x(s.values.length - 1, n), p.y(minY, max, minY))
          ..lineTo(p.x(0, n), p.y(minY, max, minY))
          ..close();
        canvas.drawPath(area, Paint()..color = s.color.withValues(alpha: 0.14));
      }
      canvas.drawPath(
        s.dashed ? dashed(path) : path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width
          ..strokeJoin = StrokeJoin.round,
      );
      if (s.endDot) {
        canvas.drawCircle(
          Offset(p.x(s.values.length - 1, n),
              p.y(s.values.last.clamp(minY, max), max, minY)),
          4,
          Paint()..color = s.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}

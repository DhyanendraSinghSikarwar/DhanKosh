import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/charts/chart_style.dart';

/// Month-end forecast fan: actual line, dashed expected path, low-high band
/// and the budget line (FR-18-13). Lists are paise; [actual] runs from day 1
/// to today and [expected], [low], [high] from today to month end.
class FanChart extends StatelessWidget {
  /// Creates the chart.
  const FanChart({
    required this.actual,
    required this.expected,
    required this.low,
    required this.high,
    required this.budget,
    required this.month,
    this.masked = false,
    this.height = 170,
    super.key,
  });

  /// Cumulative spend, day 1 to today.
  final List<int> actual;

  /// Expected cumulative spend from today.
  final List<int> expected;

  /// Low end of the range.
  final List<int> low;

  /// High end of the range.
  final List<int> high;

  /// Sum of monthly budgets; 0 draws no line.
  final int budget;

  /// First day of the forecast month (x labels).
  final DateTime month;

  /// Axis labels hidden.
  final bool masked;

  /// Chart height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = ChartStyle.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _FanPainter(this, style),
      ),
    );
  }
}

const _mon = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class _FanPainter extends CustomPainter {
  _FanPainter(this.c, this.style);

  final FanChart c;
  final ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final from = math.max(c.actual.length - 1, 0);
    final n = math.max(from + c.expected.length, 2);
    final p = Plot(size);
    final top = [
      c.budget,
      ...c.high,
      ...c.expected,
      ...c.actual,
    ].fold<double>(0, (a, v) => v > a ? v.toDouble() : a);
    final max = niceMax(top);
    paintGrid(
      canvas,
      p,
      max,
      style,
      label: (v) => axisLabel(v, masked: c.masked),
    );
    Offset pt(int i, int v) => Offset(p.x(i, n), p.y(v.toDouble(), max));
    for (final (i, t) in <(int, String)>[
      (0, '1 ${_mon[c.month.month - 1]}'),
      (10, '11'),
      (20, '21'),
      (n - 1, '$n'),
    ]) {
      if (i > n - 1) continue;
      paintText(
        canvas,
        t,
        Offset(p.x(i, n), size.height - 6),
        color: style.label,
        align: TextAlign.center,
        base: style.base,
      );
    }
    if (c.high.length > 1 && c.low.length == c.high.length) {
      final band = Path()
        ..moveTo(pt(from, c.high[0]).dx, pt(from, c.high[0]).dy);
      for (var j = 1; j < c.high.length; j++) {
        final o = pt(from + j, c.high[j]);
        band.lineTo(o.dx, o.dy);
      }
      for (var j = c.low.length - 1; j >= 0; j--) {
        final o = pt(from + j, c.low[j]);
        band.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        band..close(),
        Paint()..color = ChartColors.mint.withValues(alpha: 0.18),
      );
    }
    if (c.expected.length > 1) {
      final path = Path();
      for (final (j, v) in c.expected.indexed) {
        final o = pt(from + j, v);
        j == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        dashed(path, dash: 5),
        Paint()
          ..color = ChartColors.mint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (c.actual.length > 1) {
      final path = Path();
      for (final (i, v) in c.actual.indexed) {
        final o = pt(i, v);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = style.fg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (c.budget > 0) {
      final y = p.y(c.budget.toDouble(), max);
      canvas.drawPath(
        dashed(
          Path()
            ..moveTo(p.left, y)
            ..lineTo(p.right, y),
          dash: 2,
          gap: 3,
        ),
        Paint()
          ..color = ChartColors.red
          ..style = PaintingStyle.stroke,
      );
      paintText(
        canvas,
        'budget ${axisLabel(c.budget.toDouble(), masked: c.masked)}',
        Offset(p.right - 2, y - 7),
        color: ChartColors.red,
        align: TextAlign.right,
        base: style.base,
      );
    }
  }

  @override
  bool shouldRepaint(_FanPainter old) => true;
}

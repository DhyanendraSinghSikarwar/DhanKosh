import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/presentation/charts/chart_style.dart';

/// Single-series bars (daily spend, category by month); paise.
class BarsChart extends StatelessWidget {
  /// Creates the chart.
  const BarsChart({
    required this.values,
    required this.color,
    this.xLabels = const [],
    this.emphasiseLast = false,
    this.masked = false,
    this.height = 150,
    super.key,
  });

  /// One value per bar.
  final List<int> values;

  /// Bar colour.
  final Color color;

  /// Labels as (bar index, text).
  final List<(int, String)> xLabels;

  /// Dim every bar but the last.
  final bool emphasiseLast;

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
        painter: _BarsPainter(
          values,
          color,
          xLabels,
          emphasiseLast,
          masked,
          style,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(
    this.values,
    this.color,
    this.xLabels,
    this.emphasiseLast,
    this.masked,
    this.style,
  );

  final List<int> values;
  final Color color;
  final List<(int, String)> xLabels;
  final bool emphasiseLast;
  final bool masked;
  final ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final p = Plot(size);
    final max = niceMax(
      values.fold<double>(0, (a, v) => v > a ? v.toDouble() : a),
    );
    paintGrid(
      canvas,
      p,
      max,
      style,
      label: (v) => axisLabel(v, masked: masked),
    );
    final slot = p.width / values.length;
    final bw = (slot * 0.62).clamp(2.0, 18.0);
    for (final (i, v) in values.indexed) {
      if (v <= 0) continue;
      final x = p.left + slot * i + (slot - bw) / 2;
      final dim = emphasiseLast && i != values.length - 1;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x, p.y(v.toDouble(), max), x + bw, p.y(0, max)),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: dim ? 0.4 : 1),
      );
    }
    for (final (i, t) in xLabels) {
      paintText(
        canvas,
        t,
        Offset(p.left + slot * i + slot / 2, size.height - 6),
        color: style.label,
        align: TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}

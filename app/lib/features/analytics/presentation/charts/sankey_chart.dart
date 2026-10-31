import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/presentation/charts/chart_style.dart';

/// Income node on the left, ribbons to the spend groups on the right
/// (FR-18-09). Outputs are (label, paise, colour).
class SankeyChart extends StatelessWidget {
  /// Creates the chart.
  const SankeyChart({
    required this.income,
    required this.outputs,
    required this.format,
    this.height = 170,
    super.key,
  });

  /// Total income in paise (the left node's label).
  final int income;

  /// Right-hand nodes, top to bottom.
  final List<(String, int, Color)> outputs;

  /// Compact amount text.
  final String Function(int) format;

  /// Chart height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = ChartStyle.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SankeyPainter(income, outputs, format, style),
      ),
    );
  }
}

class _SankeyPainter extends CustomPainter {
  _SankeyPainter(this.income, this.outputs, this.format, this.style);

  final int income;
  final List<(String, int, Color)> outputs;
  final String Function(int) format;
  final ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final total = outputs.fold(0, (a, o) => a + o.$2);
    if (total <= 0) return;
    const nodeW = 8.0;
    const gap = 6.0;
    const pad = 14.0;
    final xl = size.width * 0.19;
    final xr = size.width * 0.606;
    final n = outputs.length;
    final usable = size.height - 2 * pad - gap * (n - 1);
    final hs = [
      for (final o in outputs) math.max(usable * o.$2 / total, 3.0),
    ];
    final stack = hs.fold(0.0, (a, h) => a + h) + gap * (n - 1);
    var y = pad + (size.height - 2 * pad - stack) / 2;
    final leftH = hs.fold(0.0, (a, h) => a + h);
    final leftTop = (size.height - leftH) / 2;
    var ly = leftTop;
    final mid = (xl + nodeW + xr) / 2;
    final labelY = <double>[];
    for (final (i, o) in outputs.indexed) {
      final h = hs[i];
      final path = Path()
        ..moveTo(xl + nodeW, ly)
        ..cubicTo(mid, ly, mid, y, xr, y)
        ..lineTo(xr, y + h)
        ..cubicTo(mid, y + h, mid, ly + h, xl + nodeW, ly + h)
        ..close();
      canvas.drawPath(path, Paint()..color = o.$3.withValues(alpha: 0.35));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(xr, y, nodeW, h),
          const Radius.circular(3),
        ),
        Paint()..color = o.$3,
      );
      labelY.add(y + h / 2);
      ly += h;
      y += h + gap;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(xl, leftTop, nodeW, leftH),
        const Radius.circular(3),
      ),
      Paint()..color = style.fg,
    );
    paintText(
      canvas,
      'Income',
      Offset(0, leftTop + 12),
      color: style.label,
      maxWidth: xl - 4,
    );
    paintText(
      canvas,
      format(income),
      Offset(0, leftTop + 25),
      color: style.fg,
      weight: FontWeight.w600,
      maxWidth: xl - 4,
    );
    // Keep right labels at least 13 px apart.
    for (var i = 1; i < labelY.length; i++) {
      if (labelY[i] - labelY[i - 1] < 13) labelY[i] = labelY[i - 1] + 13;
    }
    for (final (i, o) in outputs.indexed) {
      paintText(
        canvas,
        '${o.$1} ${format(o.$2)}',
        Offset(xr + nodeW + 8, labelY[i]),
        color: style.label,
        maxWidth: size.width - xr - nodeW - 8,
      );
    }
  }

  @override
  bool shouldRepaint(_SankeyPainter old) => true;
}

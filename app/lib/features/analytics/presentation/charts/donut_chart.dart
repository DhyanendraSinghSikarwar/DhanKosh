import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/presentation/charts/chart_style.dart';

/// One donut slice.
class DonutPart {
  /// Creates a slice.
  const DonutPart(this.value, this.color);

  /// Slice size.
  final int value;

  /// Slice colour.
  final Color color;
}

/// Ring chart with a 20 px stroke, a wider selected slice, dimmed rest and
/// a centre label; tap a slice to select it (FR-18-29).
class DonutChart extends StatelessWidget {
  /// Creates the chart.
  const DonutChart({
    required this.parts,
    required this.centerTop,
    required this.centerBottom,
    this.selected,
    this.onTap,
    this.size = 140,
    super.key,
  });

  /// Slices in drawing order, clockwise from the top.
  final List<DonutPart> parts;

  /// Small centre caption.
  final String centerTop;

  /// Bold centre value.
  final String centerBottom;

  /// Selected slice index.
  final int? selected;

  /// Receives the tapped slice index.
  final ValueChanged<int>? onTap;

  /// Width and height.
  final double size;

  int? _hit(Offset o) {
    final c = Offset(size / 2, size / 2);
    final r = size / 2 - 12;
    final d = o - c;
    if ((d.distance - r).abs() > 15) return null;
    final total = parts.fold(0, (a, p) => a + p.value);
    if (total <= 0) return null;
    var a = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    var acc = 0.0;
    for (final (i, p) in parts.indexed) {
      acc += 2 * math.pi * p.value / total;
      if (a <= acc) return i;
    }
    return parts.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final style = ChartStyle.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final i = _hit(d.localPosition);
        if (i != null) onTap?.call(i);
      },
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(
            parts,
            selected,
            centerTop,
            centerBottom,
            style,
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(
    this.parts,
    this.selected,
    this.centerTop,
    this.centerBottom,
    this.style,
  );

  final List<DonutPart> parts;
  final int? selected;
  final String centerTop;
  final String centerBottom;
  final ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = style.track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20,
    );
    final total = parts.fold(0, (a, p) => a + p.value);
    if (total > 0) {
      var start = -math.pi / 2;
      for (final (i, p) in parts.indexed) {
        final sweep = 2 * math.pi * p.value / total;
        final gap = parts.length > 1 ? 1.5 / r : 0.0;
        final dim = selected != null && selected != i;
        canvas.drawArc(
          rect,
          start,
          math.max(sweep - gap, 0.001),
          false,
          Paint()
            ..color = p.color.withValues(alpha: dim ? 0.35 : 1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected == i ? 26 : 20,
        );
        start += sweep;
      }
    }
    paintText(
      canvas,
      centerTop,
      Offset(c.dx, c.dy - 9),
      color: style.label,
      size: 11,
      align: TextAlign.center,
      maxWidth: r * 1.4,
    );
    paintText(
      canvas,
      centerBottom,
      Offset(c.dx, c.dy + 9),
      color: style.fg,
      size: 15,
      weight: FontWeight.w600,
      align: TextAlign.center,
      maxWidth: r * 1.4,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

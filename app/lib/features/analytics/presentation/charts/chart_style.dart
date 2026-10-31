import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chart series colours of the approved mock (mint, blue, amber, violet).
abstract final class ChartColors {
  /// Essentials, income, first series.
  static const mint = Color(0xFF8FD19E);

  /// Lifestyle, cash balance.
  static const blue = Color(0xFF7FA9E6);

  /// Other, invested.
  static const amber = Color(0xFFE3B45F);

  /// Saved, savings rate.
  static const violet = Color(0xFFB39DDB);

  /// Spent, over budget, rising change.
  static const red = Color(0xFFE8837C);

  /// Sixth category colour.
  static const teal = Color(0xFF5CB8C4);

  /// Seventh category colour.
  static const olive = Color(0xFFB5B96B);

  /// Rest of the categories.
  static const grey = Color(0xFF8C9893);

  /// Category and legend order.
  static const palette = [mint, blue, amber, violet, red, teal, olive, grey];
}

/// Theme colours shared by every analysis chart.
class ChartStyle {
  /// Creates a style.
  const ChartStyle({
    required this.grid,
    required this.label,
    required this.fg,
    required this.track,
  });

  /// Reads the style from the ambient theme.
  factory ChartStyle.of(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return ChartStyle(
      grid: s.outlineVariant,
      label: s.onSurfaceVariant,
      fg: s.onSurface,
      track: s.surfaceContainerHighest,
    );
  }

  /// Dashed grid lines.
  final Color grid;

  /// Axis labels.
  final Color label;

  /// Primary ink (running line, average line).
  final Color fg;

  /// Empty bar and ring background.
  final Color track;
}

/// Compact rupee label for an axis: 0, 500, 47K, 1.2L, 2L. Masked: `••`.
String axisLabel(double minor, {bool masked = false}) {
  if (masked) return '••';
  final v = minor.abs() / 100;
  final sign = minor < 0 ? '-' : '';
  if (v >= 100000) {
    final l = (v / 100000 * 10).round() / 10;
    return '$sign${l == l.roundToDouble() ? l.round() : l}L';
  }
  if (v >= 1000) return '$sign${(v / 1000).round()}K';
  return '$sign${v.round()}';
}

/// Compact label for a money total ("₹1.1L", "₹62K"); masked: `₹••••`.
String compactMoney(int minor, {bool masked = false}) =>
    masked ? '₹••••' : '₹${axisLabel(minor.toDouble())}';

/// Smallest round maximum at or above [max] whose thirds are round too.
double niceMax(double max) {
  if (max <= 0) return 3;
  final p = math.pow(10, (math.log(max) / math.ln10).floor()).toDouble();
  for (final c in const [1.2, 1.5, 1.8, 2.1, 2.4, 3, 3.6, 4.5, 6, 7.5, 9, 12]) {
    if (c * p >= max) return c * p;
  }
  return 12 * p;
}

/// Inner plot rectangle with the mock's padding (l 34, r 8, t 8, b 20).
class Plot {
  /// Creates a plot area inside [size].
  Plot(Size size, {double l = 34, double r = 8, double t = 8, double b = 20})
      : left = l,
        right = size.width - r,
        top = t,
        bottom = size.height - b;

  /// Left edge.
  final double left;

  /// Right edge.
  final double right;

  /// Top edge.
  final double top;

  /// Bottom edge.
  final double bottom;

  /// Width.
  double get width => right - left;

  /// Height.
  double get height => bottom - top;

  /// Y of [v] on a [min]..[max] scale.
  double y(double v, double max, [double min = 0]) =>
      top + height * (1 - (v - min) / (max - min));

  /// X of point [i] of [n] across the width.
  double x(int i, int n) =>
      n < 2 ? left + width / 2 : left + width * i / (n - 1);
}

/// Draws [text] anchored at [at]; [align] picks which side of [at] it
/// hangs from, vertically centred.
void paintText(
  Canvas canvas,
  String text,
  Offset at, {
  required Color color,
  double size = 10,
  TextAlign align = TextAlign.left,
  FontWeight? weight,
  double? maxWidth,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: size, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  final dx = switch (align) {
    TextAlign.right || TextAlign.end => at.dx - tp.width,
    TextAlign.center => at.dx - tp.width / 2,
    _ => at.dx,
  };
  tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
}

/// Dashed copy of [src].
Path dashed(Path src, {double dash = 4, double gap = 4}) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

/// Four dashed horizontal grid lines (0, 1/3, 2/3, max) with y labels.
void paintGrid(
  Canvas canvas,
  Plot p,
  double max,
  ChartStyle s, {
  required String Function(double) label,
  double min = 0,
}) {
  final paint = Paint()
    ..color = s.grid
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  for (var k = 0; k <= 3; k++) {
    final v = min + (max - min) * k / 3;
    final y = p.y(v, max, min);
    canvas.drawPath(
      dashed(
        Path()
          ..moveTo(p.left, y)
          ..lineTo(p.right, y),
        dash: 3,
      ),
      paint,
    );
    paintText(
      canvas,
      label(v),
      Offset(p.left - 4, y),
      color: s.label,
      align: TextAlign.right,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/charts/chart_style.dart';

/// Bar growing left (mint, fell) or right (red, rose) from a centre tick;
/// [fraction] is -1..1 of the half width (FR-18-16).
class DivergeBar extends StatelessWidget {
  /// Creates the bar.
  const DivergeBar({required this.fraction, super.key});

  /// Signed fraction of the half width.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final style = ChartStyle.of(context);
    return SizedBox(
      height: 10,
      width: double.infinity,
      child: CustomPaint(painter: _DivergePainter(fraction, style)),
    );
  }
}

class _DivergePainter extends CustomPainter {
  _DivergePainter(this.f, this.style);

  final double f;
  final ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = style.track,
    );
    final mid = size.width / 2;
    final w = mid * f.abs().clamp(0, 1);
    if (w > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          f >= 0
              ? Rect.fromLTWH(mid, 0, w, size.height)
              : Rect.fromLTWH(mid - w, 0, w, size.height),
          r,
        ),
        Paint()..color = f >= 0 ? ChartColors.red : ChartColors.mint,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(mid - 0.5, -2, mid + 0.5, size.height + 2),
      Paint()..color = style.label,
    );
  }

  @override
  bool shouldRepaint(_DivergePainter old) => old.f != f;
}

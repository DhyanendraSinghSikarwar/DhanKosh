import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/domain/chart_data.dart';
import 'package:hisaab/features/analytics/presentation/charts/chart_style.dart';

/// Twelve stacked month bars (Essentials, Lifestyle, Other) with a dashed
/// average line and tap-to-pick (FR-18-05, FR-18-29).
class StackedBarsChart extends StatelessWidget {
  /// Creates the chart.
  const StackedBarsChart({
    required this.bars,
    required this.labels,
    required this.average,
    this.picked,
    this.onPick,
    this.masked = false,
    this.height = 170,
    super.key,
  });

  /// One bar per month, oldest first.
  final List<StackedMonth> bars;

  /// Single-letter month labels.
  final List<String> labels;

  /// Average of all months but the last, in paise.
  final int average;

  /// Index of the picked bar.
  final int? picked;

  /// Receives the tapped bar index.
  final ValueChanged<int>? onPick;

  /// Axis labels hidden.
  final bool masked;

  /// Chart height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = ChartStyle.of(context);
    return LayoutBuilder(
      builder: (context, c) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (bars.isEmpty || onPick == null) return;
          final p = Plot(Size(c.maxWidth, height), l: 30, r: 6);
          final i = ((d.localPosition.dx - p.left) / (p.width / bars.length))
              .floor()
              .clamp(0, bars.length - 1);
          onPick!(i);
        },
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _StackedPainter(
              bars,
              labels,
              average,
              picked,
              masked,
              style,
            ),
          ),
        ),
      ),
    );
  }
}

class _StackedPainter extends CustomPainter {
  _StackedPainter(
    this.bars,
    this.labels,
    this.average,
    this.picked,
    this.masked,
    this.style,
  );

  final List<StackedMonth> bars;
  final List<String> labels;
  final int average;
  final int? picked;
  final bool masked;
  final ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final p = Plot(size, l: 30, r: 6);
    final top = bars.fold<double>(
      average.toDouble(),
      (a, b) => b.total > a ? b.total.toDouble() : a,
    );
    final max = niceMax(top);
    paintGrid(
      canvas,
      p,
      max,
      style,
      label: (v) => axisLabel(v, masked: masked),
    );
    final slot = p.width / bars.length;
    final bw = slot * 0.6;
    const cols = [ChartColors.mint, ChartColors.blue, ChartColors.amber];
    for (final (i, b) in bars.indexed) {
      final x = p.left + slot * i + (slot - bw) / 2;
      final dim = picked != null && picked != i;
      final parts = [b.essentials, b.lifestyle, b.other];
      final topIdx = parts.lastIndexWhere((v) => v > 0);
      var acc = 0;
      for (final (j, v) in parts.indexed) {
        if (v <= 0) continue;
        final r = Rect.fromLTRB(
          x,
          p.y((acc + v).toDouble(), max),
          x + bw,
          p.y(acc.toDouble(), max),
        );
        final paint = Paint()..color = cols[j].withValues(alpha: dim ? 0.4 : 1);
        canvas.drawRRect(
          j == topIdx
              ? RRect.fromRectAndCorners(
                  r,
                  topLeft: const Radius.circular(3),
                  topRight: const Radius.circular(3),
                )
              : RRect.fromRectAndRadius(r, Radius.zero),
          paint,
        );
        acc += v;
      }
      if (i < labels.length) {
        paintText(
          canvas,
          labels[i],
          Offset(x + bw / 2, size.height - 6),
          color: style.label,
          align: TextAlign.center,
        );
      }
    }
    if (average > 0) {
      final y = p.y(average.toDouble(), max);
      canvas.drawPath(
        dashed(
          Path()
            ..moveTo(p.left, y)
            ..lineTo(p.right, y),
          dash: 5,
          gap: 4,
        ),
        Paint()
          ..color = style.fg.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke,
      );
      paintText(
        canvas,
        'avg ${axisLabel(average.toDouble(), masked: masked)}',
        Offset(p.right - 2, y - 8),
        color: style.fg,
        align: TextAlign.right,
      );
    }
  }

  @override
  bool shouldRepaint(_StackedPainter old) => true;
}

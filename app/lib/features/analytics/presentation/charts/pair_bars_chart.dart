// Painters take plain constructor arguments.
// ignore_for_file: avoid_positional_boolean_parameters
import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/charts/chart_style.dart';

/// Income and spend bars side by side per month (mock "Income against
/// spend"); values in paise.
class PairBarsChart extends StatelessWidget {
  /// Creates the chart.
  const PairBarsChart({
    required this.labels,
    required this.income,
    required this.spent,
    this.masked = false,
    this.height = 140,
    super.key,
  });

  /// One-letter month labels.
  final List<String> labels;

  /// Income per month.
  final List<int> income;

  /// Spend per month.
  final List<int> spent;

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
        painter: _PairPainter(labels, income, spent, masked, style),
      ),
    );
  }
}

class _PairPainter extends CustomPainter {
  _PairPainter(this.labels, this.income, this.spent, this.masked, this.style);

  final List<String> labels;
  final List<int> income;
  final List<int> spent;
  final bool masked;
  final ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;
    final p = Plot(size, l: 30, r: 6);
    final top = [...income, ...spent]
        .fold<double>(0, (a, v) => v > a ? v.toDouble() : a);
    final max = niceMax(top);
    paintGrid(
      canvas,
      p,
      max,
      style,
      label: (v) => axisLabel(v, masked: masked),
    );
    final slot = p.width / labels.length;
    final bw = slot * 0.3;
    for (final (i, l) in labels.indexed) {
      final x0 = p.left + slot * i + slot * 0.15;
      void bar(double x, int v, Color c) {
        if (v <= 0) return;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(x, p.y(v.toDouble(), max), x + bw, p.y(0, max)),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          Paint()..color = c,
        );
      }

      bar(x0, income[i], ChartColors.mint);
      bar(x0 + bw + 2, spent[i], ChartColors.red);
      paintText(
        canvas,
        l,
        Offset(x0 + bw, size.height - 6),
        color: style.label,
        align: TextAlign.center,
        base: style.base,
      );
    }
  }

  @override
  bool shouldRepaint(_PairPainter old) => true;
}

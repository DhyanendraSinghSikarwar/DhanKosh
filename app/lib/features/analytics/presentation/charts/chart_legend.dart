import 'package:flutter/material.dart';

/// Row of colour dots with names under a chart.
class ChartLegend extends StatelessWidget {
  /// Creates the legend from (name, colour) pairs.
  const ChartLegend({required this.items, super.key});

  /// Legend entries.
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          for (final (name, color) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  name,
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

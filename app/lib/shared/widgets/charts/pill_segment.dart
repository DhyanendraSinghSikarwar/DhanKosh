import 'package:flutter/material.dart';

/// Small pill selector (Line / Bars) with a filled selected pill.
class PillSegment extends StatelessWidget {
  /// Creates the selector.
  const PillSegment({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// Option labels.
  final List<String> options;

  /// Selected index.
  final int selected;

  /// Receives the tapped index.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, o) in options.indexed)
            GestureDetector(
              key: Key('segment-$o'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: i == selected ? scheme.primaryContainer : null,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    fontSize: 12,
                    color: i == selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

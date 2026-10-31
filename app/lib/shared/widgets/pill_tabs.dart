import 'package:flutter/material.dart';

/// Compact pill segmented control (range and scope tabs): a filled track
/// with the selected pill in the primary container colour.
class PillTabs extends StatelessWidget {
  /// Creates the tabs. Each pill gets the key `<keyPrefix>-<label>`.
  const PillTabs({
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.keyPrefix = 'pill',
    super.key,
  });

  /// Pill labels.
  final List<String> labels;

  /// Index of the selected pill.
  final int selected;

  /// Called with the tapped index.
  final ValueChanged<int> onChanged;

  /// Prefix of each pill's key.
  final String keyPrefix;

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
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              key: Key('$keyPrefix-${labels[i]}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: i == selected ? scheme.primaryContainer : null,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  labels[i],
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

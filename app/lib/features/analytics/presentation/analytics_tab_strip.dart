import 'package:flutter/material.dart';

/// Pinned pill tab strip: rounded card background, four equal tabs, the
/// selected one filled with the primary container (FR-18-01).
class AnalyticsTabStrip extends SliverPersistentHeaderDelegate {
  /// Creates the delegate.
  AnalyticsTabStrip({
    required this.labels,
    required this.selected,
    required this.onSelect,
    required this.background,
  });

  /// Tab labels.
  final List<String> labels;

  /// Selected index.
  final int selected;

  /// Receives the tapped index.
  final ValueChanged<int> onSelect;

  /// Page background behind the pinned strip.
  final Color background;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Container(
          key: const Key('analytics-view'),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              for (final (i, l) in labels.indexed)
                Expanded(
                  child: GestureDetector(
                    key: Key('analytics-tab-$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(i),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: i == selected ? scheme.primaryContainer : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        l,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              i == selected ? FontWeight.w600 : FontWeight.w400,
                          color: i == selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(AnalyticsTabStrip old) =>
      old.selected != selected || old.background != background;
}

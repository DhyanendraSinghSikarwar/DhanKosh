import 'package:flutter/material.dart';

/// Compact single-select dropdown (pill button with a check-marked menu).
class AppDropdown<T> extends StatelessWidget {
  /// Creates a dropdown over [options].
  const AppDropdown({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.icon,
    this.dense = false,
    super.key,
  });

  /// Selected option.
  final T value;

  /// Options in menu order.
  final List<T> options;

  /// Text for an option.
  final String Function(T) labelOf;

  /// Called with the chosen option.
  final ValueChanged<T> onChanged;

  /// Optional leading icon.
  final IconData? icon;

  /// Smaller padding for title rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium;
    return PopupMenuButton<T>(
      tooltip: '',
      initialValue: value,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<T>(
            value: o,
            child: Row(
              children: [
                Expanded(child: Text(labelOf(o))),
                if (o == value)
                  Icon(Icons.check, size: 18, color: scheme.primary),
              ],
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 7 : 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(dense ? 12 : 14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(labelOf(value), style: style),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Filled card, radius 20, no border (the app's standard surface).
class AppCard extends StatelessWidget {
  /// Creates a card around [child].
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.margin = EdgeInsets.zero,
    super.key,
  });

  /// Card content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Outer space around the card.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );
    return Padding(
      padding: margin,
      child: Material(
        color: scheme.surfaceContainer,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

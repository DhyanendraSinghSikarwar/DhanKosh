import 'package:flutter/material.dart';

/// Uppercase 11px letter-spaced muted label that heads a card or group.
class SectionLabel extends StatelessWidget {
  /// Creates a label showing [text] in upper case.
  const SectionLabel(this.text, {this.padding = EdgeInsets.zero, super.key});

  /// Label text (upper-cased on display).
  final String text;

  /// Outer padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

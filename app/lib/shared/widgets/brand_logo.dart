import 'package:flutter/material.dart';

/// A bundled brand logo in a rounded tile (FR-09-32). Falls back to a letter
/// avatar from [label] when [logoKey] is null or has no asset. Decorative:
/// the row beside it carries the name.
class BrandLogo extends StatelessWidget {
  /// Creates the logo. [logoKey] comes from `BrandLogos`.
  const BrandLogo({
    required this.label,
    this.logoKey,
    this.size = 40,
    super.key,
  });

  /// Logo key, or null for the letter avatar.
  final String? logoKey;

  /// Name used for the fallback letter.
  final String label;

  /// Side of the square tile.
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    final key = logoKey;
    final letter = Container(
      key: const Key('brand-letter'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: radius,
      ),
      child: Text(
        label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
    if (key == null) return letter;
    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        'assets/logos/$key.webp',
        key: const Key('brand-image'),
        width: size,
        height: size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => letter,
      ),
    );
  }
}

// Generated port of tokens; deprecated surfaceVariant kept for parity with the Kotlin schemes.
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// Light scheme from a palette's tokens (port of `lightScheme`, FR-28-02).
ColorScheme lightScheme(
  Color primary,
  Color primaryContainer,
  Color onPrimaryContainer,
  Color secondary,
  Color secondaryContainer,
  Color onSecondaryContainer,
  Color tertiary,
  Color tertiaryContainer,
  Color onTertiaryContainer, {
  required Color background,
  required Color ink,
  required Color muted,
  required Color outline,
  required Color outlineVariant,
  required Color high,
  required Color highest,
  required Color inversePrimary,
}) =>
    ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: _white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: _white,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: _white,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: const Color(0xFFD2453B),
      onError: _white,
      errorContainer: const Color(0xFFFBE0DD),
      onErrorContainer: const Color(0xFF5C0E08),
      surface: background,
      onSurface: ink,
      surfaceVariant: high,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: outlineVariant,
      surfaceContainerLowest: _white,
      surfaceContainerLow: _white,
      surfaceContainer: _white,
      surfaceContainerHigh: high,
      surfaceContainerHighest: highest,
      surfaceBright: _white,
      surfaceDim: highest,
      inverseSurface: ink,
      onInverseSurface: background,
      inversePrimary: inversePrimary,
      surfaceTint: Colors.transparent,
    );

/// Dark scheme from a palette's tokens (port of `darkScheme`, FR-28-02).
ColorScheme darkScheme(
  Color primary,
  Color onPrimary,
  Color primaryContainer,
  Color onPrimaryContainer,
  Color secondary,
  Color onSecondary,
  Color secondaryContainer,
  Color onSecondaryContainer,
  Color tertiary,
  Color onTertiary,
  Color tertiaryContainer,
  Color onTertiaryContainer, {
  required Color background,
  required Color ink,
  required Color muted,
  required Color outline,
  required Color outlineVariant,
  required Color lowest,
  required Color container,
  required Color high,
  required Color highest,
  required Color bright,
  required Color inversePrimary,
}) =>
    ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: const Color(0xFFFF7B70),
      onError: const Color(0xFF4A0904),
      errorContainer: const Color(0xFF5C1A15),
      onErrorContainer: const Color(0xFFFFDAD5),
      surface: background,
      onSurface: ink,
      surfaceVariant: high,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: outlineVariant,
      surfaceContainerLowest: lowest,
      surfaceContainerLow: container,
      surfaceContainer: container,
      surfaceContainerHigh: high,
      surfaceContainerHighest: highest,
      surfaceBright: bright,
      surfaceDim: background,
      inverseSurface: ink,
      onInverseSurface: background,
      inversePrimary: inversePrimary,
      surfaceTint: Colors.transparent,
    );

/// Everything a palette paints (port of `PaletteSpec`, FR-28-02).
@immutable
class PaletteSpec {
  /// Creates a spec.
  const PaletteSpec({
    required this.light,
    required this.dark,
    required this.heroLight,
    required this.heroDark,
    required this.glows,
    required this.bottomLight,
    required this.bottomDark,
    this.glowStrength = 1,
  });

  /// Light scheme.
  final ColorScheme light;

  /// Dark scheme.
  final ColorScheme dark;

  /// Hero gradient by day.
  final List<Color> heroLight;

  /// Hero gradient by night.
  final List<Color> heroDark;

  /// Backdrop glow colours.
  final List<Color> glows;

  /// Backdrop bottom colour by day.
  final Color bottomLight;

  /// Backdrop bottom colour by night.
  final Color bottomDark;

  /// Glow multiplier.
  final double glowStrength;

  /// True-black dark scheme and backdrop (FR-28-04).
  PaletteSpec pureBlack() => PaletteSpec(
        light: light,
        dark: dark.pureBlackScheme(),
        heroLight: heroLight,
        heroDark: heroDark,
        glows: glows,
        bottomLight: bottomLight,
        bottomDark: _black,
        glowStrength: glowStrength,
      );
}

/// Pure-black surface levels (FR-28-04).
extension PureBlackScheme on ColorScheme {
  /// This scheme with OLED-black surfaces.
  ColorScheme pureBlackScheme() => copyWith(
        surface: _black,
        surfaceDim: _black,
        onInverseSurface: _black,
        surfaceContainerLowest: _black,
        surfaceContainerLow: const Color(0xFF0B0B0D),
        surfaceContainer: const Color(0xFF0B0B0D),
        surfaceContainerHigh: const Color(0xFF141417),
        surfaceContainerHighest: const Color(0xFF1B1B1F),
        surfaceBright: const Color(0xFF222226),
        surfaceVariant: const Color(0xFF141417),
      );
}

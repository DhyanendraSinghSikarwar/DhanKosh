import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/palettes.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';

abstract final class AppTheme {
  static const Color seed = Color(0xFF1B6B5A);

  /// Default (DhanKosh) light theme.
  static ThemeData light() => build(PaletteId.dhankosh, Brightness.light);

  /// Default (DhanKosh) dark theme.
  static ThemeData dark() => build(PaletteId.dhankosh, Brightness.dark);

  /// Theme for [palette] (FR-28-01, FR-28-04, FR-28-06, FR-28-07).
  /// Material You dynamic colour is never used.
  static ThemeData build(
    PaletteId palette,
    Brightness b, {
    bool pureBlack = false,
  }) {
    var spec = allPaletteSpecs[palette.index];
    if (pureBlack && b == Brightness.dark) spec = spec.pureBlack();
    final scheme = b == Brightness.dark ? spec.dark : spec.light;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _tabular(base.textTheme),
      extensions: [
        if (b == Brightness.dark) SemanticColors.dark else SemanticColors.light,
      ],
    );
  }

  static TextTheme _tabular(TextTheme t) {
    TextStyle? f(TextStyle? s) => s?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return TextTheme(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    );
  }
}

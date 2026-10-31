import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/backdrop.dart';
import 'package:hisaab/app/theme/palettes.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';

abstract final class AppTheme {
  static const Color seed = Color(0xFF1B6B5A);

  /// Default (Mint) light theme.
  static ThemeData light() => build(PaletteId.mint, Brightness.light);

  /// Default (Mint) dark theme.
  static ThemeData dark() => build(PaletteId.mint, Brightness.dark);

  /// Theme for [palette]; [backdrop] adds the wash and glows (FR-28-08), off
  /// on true black. (FR-28-01, FR-28-04, FR-28-06, FR-28-07).
  /// Material You dynamic colour is never used.
  static ThemeData build(
    PaletteId palette,
    Brightness b, {
    bool pureBlack = false,
    bool backdrop = false,
  }) {
    var spec = allPaletteSpecs[palette.index];
    if (pureBlack && b == Brightness.dark) spec = spec.pureBlack();
    final scheme = b == Brightness.dark ? spec.dark : spec.light;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    // The backdrop is off on true black (no gradients over pure black).
    final withBackdrop = backdrop && !(pureBlack && b == Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor:
          withBackdrop ? Colors.transparent : scheme.surface,
      pageTransitionsTheme: withBackdrop
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: BackdropPageTransitionsBuilder(),
                TargetPlatform.iOS: BackdropPageTransitionsBuilder(),
                TargetPlatform.linux: BackdropPageTransitionsBuilder(),
                TargetPlatform.macOS: BackdropPageTransitionsBuilder(),
                TargetPlatform.windows: BackdropPageTransitionsBuilder(),
              },
            )
          : null,
      textTheme: _tabular(base.textTheme),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      extensions: [
        if (b == Brightness.dark) SemanticColors.dark else SemanticColors.light,
        if (withBackdrop)
          BackdropTheme(
            base: scheme.surface,
            bottom: b == Brightness.dark ? spec.bottomDark : spec.bottomLight,
            glows: spec.glows,
            dark: b == Brightness.dark,
            glowStrength: spec.glowStrength,
          ),
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

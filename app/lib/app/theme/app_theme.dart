import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';

abstract final class AppTheme {
  static const Color seed = Color(0xFF1B6B5A);

  static ThemeData light() => _build(Brightness.light, SemanticColors.light);
  static ThemeData dark() => _build(Brightness.dark, SemanticColors.dark);

  static ThemeData _build(Brightness b, SemanticColors semantic) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b),
      extensions: [semantic],
    );
  }
}

import 'package:flutter/material.dart';

/// Semantic (non-Material) colours: income, expense, warning.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.income,
    required this.expense,
    required this.warning,
  });

  static const light = SemanticColors(
    income: Color(0xFF13895A),
    expense: Color(0xFFD2453B),
    warning: Color(0xFFC98A0B),
  );
  static const dark = SemanticColors(
    income: Color(0xFF3CCB8B),
    expense: Color(0xFFFF7B70),
    warning: Color(0xFFF2B84B),
  );

  final Color income;
  final Color expense;
  final Color warning;

  @override
  SemanticColors copyWith({Color? income, Color? expense, Color? warning}) =>
      SemanticColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        warning: warning ?? this.warning,
      );

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

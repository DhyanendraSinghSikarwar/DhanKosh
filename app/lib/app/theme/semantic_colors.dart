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
    income: Color(0xFF2E7D32),
    expense: Color(0xFFC62828),
    warning: Color(0xFFEF6C00),
  );
  static const dark = SemanticColors(
    income: Color(0xFF81C784),
    expense: Color(0xFFEF9A9A),
    warning: Color(0xFFFFB74D),
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

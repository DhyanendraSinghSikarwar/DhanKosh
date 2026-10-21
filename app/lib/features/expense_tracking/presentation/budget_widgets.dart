import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';

/// Colour of a [BudgetBand] (FR-10-10, FR-10-14).
Color bandColor(BuildContext context, BudgetBand band) {
  final colors = Theme.of(context).extension<SemanticColors>();
  return switch (band) {
    BudgetBand.red => colors?.expense ?? Colors.red,
    BudgetBand.amber => colors?.warning ?? Colors.orange,
    BudgetBand.normal => Theme.of(context).colorScheme.primary,
  };
}

/// Parses rupee text like `12,500.5` to paise without floats; null if invalid.
int? parseRupeesToMinor(String text) {
  final t = text.replaceAll(',', '').trim();
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final frac = (m.group(2) ?? '').padRight(2, '0');
  return int.parse(m.group(1)!) * 100 + int.parse(frac);
}

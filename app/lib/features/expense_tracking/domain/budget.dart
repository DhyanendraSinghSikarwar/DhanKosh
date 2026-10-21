import 'package:parser_core/parser_core.dart';

/// A monthly limit for one category, paise (FR-10-09).
class Budget {
  /// Creates a budget.
  const Budget({required this.category, required this.monthlyLimitMinor});

  final Category category;
  final int monthlyLimitMinor;
}

/// Colour band of a budget card (FR-10-10, FR-10-14).
enum BudgetBand { normal, amber, red }

/// One budget with its spend (FR-10-10).
class BudgetUse {
  /// Creates a use line.
  const BudgetUse({
    required this.category,
    required this.limitMinor,
    required this.spentMinor,
  });

  final Category category;
  final int limitMinor;
  final int spentMinor;

  /// `spent / limit`; 0 when the limit is 0.
  double get fraction => limitMinor <= 0 ? 0 : spentMinor / limitMinor;

  /// Paise left, negative when over.
  int get leftMinor => limitMinor - spentMinor;
}

/// Budgets overview (FR-10-15).
class BudgetSummary {
  /// Creates a summary.
  const BudgetSummary({
    required this.lines,
    required this.months,
    required this.alertPercent,
    this.pace,
  });

  /// Sorted by `spent/limit` descending.
  final List<BudgetUse> lines;
  final int months;
  final int alertPercent;

  /// Month fraction elapsed, only for a single current month.
  final double? pace;

  int get totalLimitMinor => lines.fold(0, (s, l) => s + l.limitMinor);
  int get totalSpentMinor => lines.fold(0, (s, l) => s + l.spentMinor);
}

/// A budget alert that should fire (FR-10-11).
class BudgetAlertHit {
  /// Creates a hit.
  const BudgetAlertHit({
    required this.category,
    required this.level,
    required this.key,
  });

  final Category category;

  /// Percent level reached (user percent or 100).
  final int level;

  /// `budget:<CAT>:<yyyy-MM>:<level>`.
  final String key;
}

import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:parser_core/parser_core.dart';

/// Pure budget maths (memory 10 section 10). Money is paise.
abstract final class BudgetMath {
  /// Categories that cannot have a budget (FR-10-09).
  static const Set<Category> excluded = {
    Category.salary,
    Category.income,
    Category.refund,
    Category.transfer,
  };

  /// Alert levels the user may choose (FR-10-12).
  static const alertChoices = [80, 90, 95];

  /// Canonical default. Decision (memory 10 open question 2): 90 everywhere;
  /// the Kotlin analytics fallback of 80 is dropped.
  static const defaultAlertPercent = 90;

  /// Alert entries kept in the dedupe store.
  static const alertedKeysCap = 300;

  /// True when [c] may carry a budget.
  static bool isBudgetable(Category c) => !excluded.contains(c);

  /// [percent] when within 1..100, else [defaultAlertPercent].
  static int normaliseAlertPercent(int? percent) =>
      percent != null && percent >= 1 && percent <= 100
          ? percent
          : defaultAlertPercent;

  /// Card colour: over limit red, at the alert level amber (FR-10-10).
  static BudgetBand band(int used, int limit, int alertPercent) {
    if (used > limit) return BudgetBand.red;
    if (used * 100 >= alertPercent * limit) return BudgetBand.amber;
    return BudgetBand.normal;
  }

  /// Home ring colour: amber at 80%, red above 100% (FR-10-14).
  static BudgetBand ringBand(int used, int limit) => band(used, limit, 80);

  /// Days left including today.
  static int daysLeft(int year, int month, int dayOfMonth) =>
      DateTime.utc(year, month + 1, 0).day - dayOfMonth + 1;

  /// Paise per remaining day, or null when over or no days (FR-10-10).
  static int? dailyLeft(int limit, int spent, int daysLeft) {
    if (spent >= limit || daysLeft <= 0) return null;
    return (limit - spent) ~/ daysLeft;
  }

  /// Limit over a span of months (FR-10-15).
  static int analyticsLimit(int monthlyLimit, int monthsSpanned) =>
      monthlyLimit * monthsSpanned;

  /// `dayOfMonth / lengthOfMonth` for a single current month, else null.
  static double? paceTick({
    required bool singleCurrentMonth,
    required int dayOfMonth,
    required int lengthOfMonth,
  }) =>
      singleCurrentMonth ? dayOfMonth / lengthOfMonth : null;

  /// Distinct levels, highest first.
  static List<int> levels(int alertPercent) =>
      {alertPercent, 100}.toList()..sort((a, b) => b.compareTo(a));

  /// The single alert to send for the budget this month, or null (FR-10-11): the
  /// highest reached level whose key is not in [alerted].
  static BudgetAlertHit? pendingAlert({
    required Budget budget,
    required int usedMinor,
    required int alertPercent,
    required String yearMonth,
    required Set<String> alerted,
  }) {
    for (final level in levels(alertPercent)) {
      if (usedMinor * 100 < budget.monthlyLimitMinor * level) continue;
      final key = 'budget:${budget.category.name.toUpperCaseSnake()}'
          ':$yearMonth:$level';
      if (alerted.contains(key)) return null;
      return BudgetAlertHit(
        category: budget.category,
        level: level,
        key: key,
      );
    }
    return null;
  }

  /// Budget lines sorted by `spent/limit` descending (FR-10-10).
  static List<BudgetUse> sortedUse(
    List<Budget> budgets,
    Map<Category, int> spentByCategory, {
    int months = 1,
  }) {
    final out = [
      for (final b in budgets)
        BudgetUse(
          category: b.category,
          limitMinor: analyticsLimit(b.monthlyLimitMinor, months),
          spentMinor: spentByCategory[b.category] ?? 0,
        ),
    ]..sort((a, b) => b.fraction.compareTo(a.fraction));
    return out;
  }
}

/// `emiLoan` -> `EMI_LOAN` (the stored enum text).
extension UpperCaseSnake on String {
  /// Converts lowerCamelCase to SNAKE_UPPER.
  String toUpperCaseSnake() => replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '_${m[0]}',
      ).toUpperCase();
}

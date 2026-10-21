import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:parser_core/parser_core.dart';

/// Budgets and period spend per category (F-10).
abstract interface class BudgetRepository {
  /// All budgets (FR-10-09).
  Stream<List<Budget>> watchAll();

  /// Current budgets.
  Future<List<Budget>> all();

  /// Creates or replaces the budget of [category] (FR-10-09).
  /// Throws [ArgumentError] for an excluded category or a limit <= 0.
  Future<void> save(Category category, int monthlyLimitMinor);

  /// Removes the budget of [category].
  Future<void> delete(Category category);

  /// Spend per category in [fromMs]..[toMs] inclusive: DEBIT + INVESTMENT
  /// with a priced `inrMinor` (parity with Kotlin `observeCategoryTotals`,
  /// no needsReview / duplicate filter; see memory 10 section 17).
  Future<Map<Category, int>> categoryTotals(int fromMs, int toMs);

  /// Live [categoryTotals].
  Stream<Map<Category, int>> watchCategoryTotals(int fromMs, int toMs);
}

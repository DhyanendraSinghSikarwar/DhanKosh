import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_math.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_repository.dart';
import 'package:parser_core/parser_core.dart';

/// [BudgetRepository] over `budgets` and read-only `transactions` queries.
class BudgetRepositoryImpl implements BudgetRepository {
  /// Creates the repository.
  BudgetRepositoryImpl(this._db);

  final AppDatabase _db;

  Budget? _map(BudgetRow r) {
    final c = enumFromDbOrNull(Category.values, r.category);
    return c == null
        ? null
        : Budget(category: c, monthlyLimitMinor: r.monthlyLimitMinor);
  }

  List<Budget> _maps(List<BudgetRow> rows) => [
        for (final r in rows)
          if (_map(r) case final b?) b,
      ];

  @override
  Stream<List<Budget>> watchAll() => _db.select(_db.budgets).watch().map(_maps);

  @override
  Future<List<Budget>> all() async =>
      _maps(await _db.select(_db.budgets).get());

  @override
  Future<void> save(Category category, int monthlyLimitMinor) async {
    if (!BudgetMath.isBudgetable(category)) {
      throw ArgumentError('No budget for ${category.name}');
    }
    if (monthlyLimitMinor <= 0) throw ArgumentError('Limit must be > 0');
    await _db.into(_db.budgets).insertOnConflictUpdate(
          BudgetsCompanion.insert(
            category: enumToDb(category),
            monthlyLimitMinor: monthlyLimitMinor,
          ),
        );
  }

  @override
  Future<void> delete(Category category) => (_db.delete(_db.budgets)
        ..where((t) => t.category.equals(enumToDb(category))))
      .go();

  static const _sql =
      'SELECT category, SUM(inr_minor) AS total FROM transactions '
      "WHERE type IN ('DEBIT','INVESTMENT') AND inr_minor IS NOT NULL "
      'AND timestamp BETWEEN ?1 AND ?2 GROUP BY category ORDER BY total DESC';

  Map<Category, int> _fold(List<MapEntry<Category?, int>> rows) => {
        for (final e in rows)
          if (e.key != null) e.key!: e.value,
      };

  @override
  Future<Map<Category, int>> categoryTotals(int fromMs, int toMs) async =>
      _fold(await _entries(fromMs, toMs).get());

  @override
  Stream<Map<Category, int>> watchCategoryTotals(int fromMs, int toMs) =>
      _entries(fromMs, toMs).watch().map(_fold);

  Selectable<MapEntry<Category?, int>> _entries(int fromMs, int toMs) =>
      _db.customSelect(
        _sql,
        variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
        readsFrom: {_db.transactions},
      ).map(
        (r) => MapEntry(
          enumFromDbOrNull(Category.values, r.read<String>('category')),
          r.read<int>('total'),
        ),
      );
}

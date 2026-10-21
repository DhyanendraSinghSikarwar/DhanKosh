import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/income_tracking/domain/cash_flow.dart';
import 'package:hisaab/features/income_tracking/domain/income_repository.dart';

/// [IncomeRepository] with read-only queries on `transactions`.
class IncomeRepositoryImpl implements IncomeRepository {
  /// Creates the repository.
  IncomeRepositoryImpl(this._db);

  final AppDatabase _db;

  static const _live = 'needs_review = 0 AND duplicate_of_id IS NULL '
      "AND category != 'TRANSFER'";

  @override
  Future<int> incomeBetween(int fromMs, int toMs) async {
    final r = await _db.customSelect(
      'SELECT COALESCE(SUM(inr_minor),0) AS v FROM transactions '
      "WHERE type = 'CREDIT' AND $_live AND timestamp BETWEEN ?1 AND ?2",
      variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
      readsFrom: {_db.transactions},
    ).getSingle();
    return r.read<int>('v');
  }

  static const _flowSql = '''
SELECT
 COALESCE(SUM(CASE WHEN type='CREDIT' THEN inr_minor END),0) AS income,
 COALESCE(SUM(CASE WHEN type='DEBIT' THEN inr_minor END),0) AS spent,
 COALESCE(SUM(CASE WHEN type='INVESTMENT' THEN inr_minor END),0) AS invested
FROM transactions WHERE $_live AND timestamp BETWEEN ?1 AND ?2''';

  @override
  Future<CashFlow> cashFlow(int fromMs, int toMs) async {
    final r = await _db.customSelect(
      _flowSql,
      variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
      readsFrom: {_db.transactions},
    ).getSingle();
    return CashFlow(
      incomeMinor: r.read<int>('income'),
      spentMinor: r.read<int>('spent'),
      investedMinor: r.read<int>('invested'),
    );
  }

  static const _monthSql = '''
SELECT strftime('%Y-%m', (timestamp + 19800000) / 1000, 'unixepoch') AS ym,
 COALESCE(SUM(CASE WHEN type='CREDIT' THEN inr_minor END),0) AS income,
 COALESCE(SUM(CASE WHEN type='DEBIT' THEN inr_minor END),0) AS spent,
 COALESCE(SUM(CASE WHEN type='INVESTMENT' THEN inr_minor END),0) AS invested
FROM transactions WHERE $_live AND timestamp BETWEEN ?1 AND ?2
GROUP BY ym ORDER BY ym''';

  Selectable<MonthFlow> _months(int fromMs, int toMs) => _db.customSelect(
        _monthSql,
        variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
        readsFrom: {_db.transactions},
      ).map(
        (r) => MonthFlow(
          yearMonth: r.read<String>('ym'),
          incomeMinor: r.read<int>('income'),
          spentMinor: r.read<int>('spent'),
          investedMinor: r.read<int>('invested'),
        ),
      );

  @override
  Future<List<MonthFlow>> monthlyFlows(int fromMs, int toMs) =>
      _months(fromMs, toMs).get();

  @override
  Stream<List<MonthFlow>> watchMonthlyFlows(int fromMs, int toMs) =>
      _months(fromMs, toMs).watch();
}

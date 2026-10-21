import 'package:hisaab/features/income_tracking/domain/cash_flow.dart';

/// Persistence-backed income reads (F-11). The ledger owns the rows.
abstract interface class IncomeRepository {
  /// Sum of `inrMinor` of non-TRANSFER, non-review, non-duplicate CREDIT rows
  /// in [fromMs]..[toMs] (FR-11-05).
  Future<int> incomeBetween(int fromMs, int toMs);

  /// Income, spent and invested for the period (FR-11-06).
  Future<CashFlow> cashFlow(int fromMs, int toMs);

  /// Per IST month totals in the window, oldest first (FR-11-09).
  Future<List<MonthFlow>> monthlyFlows(int fromMs, int toMs);

  /// Live [monthlyFlows].
  Stream<List<MonthFlow>> watchMonthlyFlows(int fromMs, int toMs);
}

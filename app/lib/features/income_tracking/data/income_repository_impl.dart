import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/income_tracking/domain/cash_flow.dart';
import 'package:hisaab/features/income_tracking/domain/income_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/transfer_pairing.dart';

/// [IncomeRepository] with read-only queries on `transactions`.
class IncomeRepositoryImpl implements IncomeRepository {
  /// Creates the repository.
  IncomeRepositoryImpl(this._tx);

  final TransactionRepository _tx;

  // ADR-0011: totals come from SpendCalc (cash basis); the card payment
  // window around the range only serves to pair payments.
  Stream<List<LedgerTx>> _rows(int fromMs, int toMs) => _tx.watch(
        LedgerFilter(
          fromMs: fromMs - TransferPairing.cardWindowMs,
          toMs: toMs + 1 + TransferPairing.cardWindowMs,
        ),
      );

  static CashFlow _flow(CashTotals c) => CashFlow(
        incomeMinor: c.incomeMinor + c.refundMinor,
        spentMinor: c.spentMinor,
        investedMinor: c.investedMinor,
      );

  @override
  Future<int> incomeBetween(int fromMs, int toMs) async =>
      (await cashFlow(fromMs, toMs)).incomeMinor;

  @override
  Future<CashFlow> cashFlow(int fromMs, int toMs) async {
    final all = await _rows(fromMs, toMs).first;
    final inRange =
        all.where((t) => t.timestamp >= fromMs && t.timestamp <= toMs);
    return _flow(SpendCalc.totals(inRange, context: all));
  }

  static const _istMs = 19800000;

  List<MonthFlow> _byMonth(List<LedgerTx> all, int fromMs, int toMs) {
    final by = <String, List<LedgerTx>>{};
    for (final t in all) {
      if (t.timestamp < fromMs || t.timestamp > toMs) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(
        t.timestamp + _istMs,
        isUtc: true,
      );
      final ym = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      by.putIfAbsent(ym, () => []).add(t);
    }
    final keys = by.keys.toList()..sort();
    return [
      for (final k in keys)
        () {
          final f = _flow(SpendCalc.totals(by[k]!, context: all));
          return MonthFlow(
            yearMonth: k,
            incomeMinor: f.incomeMinor,
            spentMinor: f.spentMinor,
            investedMinor: f.investedMinor,
          );
        }(),
    ];
  }

  @override
  Future<List<MonthFlow>> monthlyFlows(int fromMs, int toMs) async =>
      _byMonth(await _rows(fromMs, toMs).first, fromMs, toMs);

  @override
  Stream<List<MonthFlow>> watchMonthlyFlows(int fromMs, int toMs) =>
      _rows(fromMs, toMs).map((all) => _byMonth(all, fromMs, toMs));
}

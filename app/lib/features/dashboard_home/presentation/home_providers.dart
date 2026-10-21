import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_providers.g.dart';

/// The month Home shows (FR-17-06); never later than the current month.
@riverpod
class HomeMonth extends _$HomeMonth {
  @override
  MonthRange build() => MonthRange.of(DateTime.now());

  void previous() => state = state.previous;

  void next() {
    if (!state.isCurrent(DateTime.now())) state = state.next;
  }
}

/// Spent / income for the shown month.
@riverpod
Stream<PeriodTotals> homeTotals(Ref ref) {
  final m = ref.watch(homeMonthProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchTotals(fromMs: m.startMs, toMs: m.endMs);
}

/// Latest transactions (FR-17-12).
@riverpod
Stream<List<LedgerTx>> homeRecent(Ref ref) =>
    ref.watch(transactionRepositoryProvider).watchRecent(4);

/// Flagged rows awaiting a decision.
@riverpod
Stream<int> homeReviewCount(Ref ref) =>
    ref.watch(transactionRepositoryProvider).watchReviewCount();

/// Visible accounts with balances for the strip.
@riverpod
Stream<List<AccountWithActivity>> homeAccounts(Ref ref) {
  final m = MonthRange.of(DateTime.now());
  return ref
      .watch(accountRepositoryProvider)
      .watchWithActivity(monthStartMs: m.startMs, monthEndMs: m.endMs);
}

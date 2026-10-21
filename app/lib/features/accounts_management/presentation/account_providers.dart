import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_providers.g.dart';

/// Visible accounts with balances and this month's spend (FR-13-04, 07).
@riverpod
Stream<List<AccountWithActivity>> accountsWithActivity(Ref ref) {
  final m = MonthRange.of(DateTime.now());
  return ref
      .watch(accountRepositoryProvider)
      .watchWithActivity(monthStartMs: m.startMs, monthEndMs: m.endMs);
}

/// Hidden accounts (FR-13-10).
@riverpod
Stream<List<Account>> hiddenAccounts(Ref ref) =>
    ref.watch(accountRepositoryProvider).watchHidden();

/// Latest activity of one account, including merged children (FR-13-17).
@riverpod
Stream<List<LedgerTx>> accountActivity(Ref ref, int accountId) => ref
    .watch(transactionRepositoryProvider)
    .watch(LedgerFilter(accountId: accountId), limit: 10);

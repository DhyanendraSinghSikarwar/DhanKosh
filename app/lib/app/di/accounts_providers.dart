import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/data/account_admin_repository_impl.dart';
import 'package:hisaab/features/accounts_management/domain/account_admin_repository.dart';
import 'package:hisaab/features/accounts_management/domain/untracked_gap.dart';
import 'package:hisaab/features/accounts_management/domain/untracked_gap_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'accounts_providers.g.dart';

/// Account personalisation, merge and restore (F-13).
@Riverpod(keepAlive: true)
AccountAdminRepository accountAdminRepository(Ref ref) =>
    AccountAdminRepositoryImpl(ref.watch(appDatabaseProvider));

/// Untracked-gap detection and follow-ups (FR-13-15).
@Riverpod(keepAlive: true)
UntrackedGapService untrackedGapService(Ref ref) => UntrackedGapService(
      accounts: ref.watch(accountAdminRepositoryProvider),
      transactions: ref.watch(transactionRepositoryProvider),
      settings: ref.watch(settingsRepositoryProvider),
    );

/// Open gaps, refreshed whenever accounts change (FR-13-15).
@riverpod
Future<List<UntrackedGap>> openGaps(Ref ref) {
  // Re-evaluates when the account list or the ledger moves.
  ref
    ..watch(accountsChangedProvider)
    ..watch(untrackedGapServiceProvider);
  return ref.read(untrackedGapServiceProvider).openGaps();
}

/// Ticks (1, 2, ...) each time accounts or their ledger figures change.
@riverpod
Stream<int> accountsChanged(Ref ref) {
  var n = 0;
  return ref
      .watch(accountRepositoryProvider)
      .watchWithActivity(monthStartMs: 0, monthEndMs: 1)
      .map((_) => ++n);
}

import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:parser_core/parser_core.dart';

abstract interface class AccountRepository {
  /// Finds or creates the account a parsed message belongs to (FR-13-01..03).
  ///
  /// Null when there is no last4, the digits are in [phoneLast4s], or an APP
  /// source finds no existing match. Joins an open DB transaction.
  Future<int?> ensureAccount(
    ParsedTransaction tx, {
    Set<String> phoneLast4s = const {},
  });

  /// Reported balance/limit; applied only if [at] is not older than the last
  /// one, null leaves the old value (FR-13-07).
  Future<void> updateBalance(
    int accountId, {
    required int at,
    int? balanceMinor,
    int? limitMinor,
  });

  Future<Account?> byId(int id);

  /// Adds an account; null when (bank, last4) already exists.
  Future<int?> create(NewAccount account);

  Future<void> rename(int id, String? nickname);
  Future<void> setType(int id, AccountType? type);
  Future<void> setManualBalance(int id, int? balanceMinor, int? at);
  Future<void> setHidden(int id, {required bool hidden});

  /// Display-only merge; null target unmerges (FR-13-08).
  Future<void> setMergedInto(int id, int? targetId);

  /// Removes the account; its transactions stay account-less (FR-13-11).
  /// Delete the transactions first (with tombstones) to remove them too.
  Future<void> delete(int id);

  /// Visible accounts (not hidden, not merged away), by bank then last4.
  Stream<List<Account>> watchVisible();

  /// Hidden accounts.
  Stream<List<Account>> watchHidden();

  /// Visible accounts with derived balance figures; [monthStartMs] to
  /// [monthEndMs] (exclusive) bounds `monthSpent`.
  Stream<List<AccountWithActivity>> watchWithActivity({
    required int monthStartMs,
    required int monthEndMs,
  });
}

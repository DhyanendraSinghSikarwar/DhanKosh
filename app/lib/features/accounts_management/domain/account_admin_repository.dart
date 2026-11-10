import 'package:hisaab/features/accounts_management/domain/account.dart';

/// An account the user chose to ignore (FR-13-22).
class IgnoredAccount {
  /// Creates an entry.
  const IgnoredAccount(this.bankName, this.last4, this.ignoredAt);

  final String bankName;
  final String last4;

  /// Epoch ms.
  final int ignoredAt;
}

/// An account-less row that restore can re-attach (FR-13-12).
class OrphanRow {
  /// Creates an orphan.
  const OrphanRow(this.transactionId, this.accountId);

  final int transactionId;

  /// Account created or found for the row.
  final int accountId;
}

/// Personalisation, merge and restore operations on accounts (FR-13-06,
/// FR-13-08, FR-13-09, FR-13-12). Never writes `transactions`.
abstract interface class AccountAdminRepository {
  /// Every account, including hidden and merged-away ones.
  Future<List<Account>> all();

  Future<void> setColor(int id, int? argb);
  Future<void> setNetwork(int id, CardNetwork? network);

  /// Links a debit card to a bank account; null unlinks.
  Future<void> setLinkedAccount(int id, int? accountId);
  Future<void> setUsage(int id, AccountUsage usage);

  /// Card forex markup in basis points (0..2000); null clears (FR-14-15).
  Future<void> setForexMarkupBps(int id, int? bps);
  Future<int?> forexMarkupBps(int id);

  /// Display-only merge of [sourceId] into [targetId]; whatever was shown with
  /// the source follows it (FR-13-08).
  Future<void> merge(int sourceId, int targetId);

  /// Undoes a merge.
  Future<void> unmerge(int id);

  /// Accounts merged into [id].
  Future<List<Account>> mergedChildren(int id);

  /// Remembers the bank and last 4 of [id] so later messages for it are
  /// dropped at ingest (FR-13-22). The account itself stays until the caller
  /// deletes it (see `deleteAccountWithOptions`).
  Future<void> ignore(int id);

  /// Accounts being ignored, newest first.
  Future<List<IgnoredAccount>> ignored();

  /// Whether messages for [bankName] and [last4] are dropped.
  Future<bool> isIgnored(String bankName, String last4);

  /// Tracks [bankName] [last4] again; its past messages are not recovered.
  Future<void> unignore(String bankName, String last4);

  /// Creates accounts for account-less rows that carry bank and last 4 and
  /// returns the rows to attach through the ledger repository (FR-13-12).
  Future<List<OrphanRow>> restoreMissing();

  /// Deletes accounts the app made by mistake: an unknown bank name or the
  /// tail of the user's own phone number, with no typed balance, nickname or
  /// reported figure (FR-13-24). Their rows stay, account-less. Returns how
  /// many were removed.
  Future<int> removeWrongAccounts(Set<String> ownTails);
}

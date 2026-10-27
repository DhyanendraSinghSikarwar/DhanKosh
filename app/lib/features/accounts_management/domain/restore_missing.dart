import 'package:hisaab/features/accounts_management/domain/account_admin_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';

/// Rebuilds accounts for account-less rows and attaches the rows through the
/// ledger repository; returns how many accounts received rows (FR-13-12).
/// Nothing is deleted or moved to another account.
Future<int> restoreMissingAccounts(
  AccountAdminRepository admin,
  TransactionRepository transactions,
) async {
  final rows = await admin.restoreMissing();
  for (final r in rows) {
    await transactions.setAccount(r.transactionId, r.accountId);
  }
  return {for (final r in rows) r.accountId}.length;
}

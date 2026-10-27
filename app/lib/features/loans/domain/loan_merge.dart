import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/loans/domain/loan_link_repository.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// Merge, unmerge and "Not duplicates" for loan accounts (FR-15-12). A merge
/// is display only (`mergedIntoId`); nothing is deleted and Unmerge restores
/// it.
class LoanMergeActions {
  /// Creates the actions.
  LoanMergeActions({
    required AccountRepository accounts,
    required LoanLinkRepository links,
    required SettingsRepository settings,
  })  : _accounts = accounts,
        _links = links,
        _settings = settings;

  /// Settings list holding ignored `LoanDuplicate.key`s.
  static const ignoredName = 'loan_dup_ignored';

  final AccountRepository _accounts;
  final LoanLinkRepository _links;
  final SettingsRepository _settings;

  /// Keys marked "Not duplicates".
  Future<Set<String>> ignoredKeys() async =>
      (await _settings.readList(ignoredName)).toSet();

  /// Merges [d].from into [d].into; links to the merged loan move over.
  Future<bool> merge(LoanDuplicate d) async {
    final from = d.from.accountId;
    final into = d.into.accountId;
    if (from == null || into == null || from == into) return false;
    await _links.clearLoan(from);
    await _accounts.setMergedInto(from, into);
    return true;
  }

  /// Undoes a merge of account [accountId].
  Future<void> unmerge(int accountId) =>
      _accounts.setMergedInto(accountId, null);

  /// Remembers that [d] is not a duplicate.
  Future<void> notDuplicates(LoanDuplicate d) =>
      _settings.appendCapped(ignoredName, d.key);
}

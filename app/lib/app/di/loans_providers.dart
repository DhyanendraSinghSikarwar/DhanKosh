import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/loans/domain/loan_builder.dart';
import 'package:hisaab/features/loans/domain/loan_merge.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'loans_providers.g.dart';

// F-15 loan merge wiring (FR-15-12).

/// Merge, unmerge and "Not duplicates".
@Riverpod(keepAlive: true)
LoanMergeActions loanMergeActions(Ref ref) => LoanMergeActions(
      accounts: ref.watch(accountRepositoryProvider),
      links: ref.watch(loanLinkRepositoryProvider),
      settings: ref.watch(settingsRepositoryProvider),
    );

/// Likely duplicate loans; invalidate after a merge decision.
@riverpod
Future<List<LoanDuplicate>> loanDuplicates(Ref ref) async {
  final state = await ref.watch(loansStateProvider.future);
  final ignored = await ref.watch(loanMergeActionsProvider).ignoredKeys();
  return Loans.duplicates(state.loans, ignored: ignored);
}

/// Loan accounts merged into [loanAccountId].
@riverpod
Future<List<LoanAccount>> mergedLoanAccounts(Ref ref, int loanAccountId) async {
  final book = await ref.watch(loanBookProvider.future);
  return [
    for (final a in book.merged)
      if (a.mergedIntoId == loanAccountId) a,
  ];
}

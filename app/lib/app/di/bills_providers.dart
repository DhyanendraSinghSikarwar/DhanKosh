import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/loans/data/loan_account_repository_impl.dart';
import 'package:hisaab/features/loans/domain/loan_account_repository.dart';
import 'package:hisaab/features/loans/domain/loan_builder.dart';
import 'package:hisaab/features/loans/domain/loan_link_repository.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/features/recurring_transactions/domain/bills_view.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_detector.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bills_providers.g.dart';

// Bills (F-12) and Loans (F-15) UI wiring. Presentation reads domain only.

/// Loan accounts (F-15).
@Riverpod(keepAlive: true)
LoanAccountRepository loanAccountRepository(Ref ref) =>
    LoanAccountRepositoryImpl(ref.watch(appDatabaseProvider));

/// Loan accounts, live (F-15).
@riverpod
Stream<LoanBook> loanBook(Ref ref) =>
    ref.watch(loanAccountRepositoryProvider).watch();

/// Loan links and dismissals, live (F-15).
@riverpod
Stream<LoanLinkSet> loanLinkSet(Ref ref) =>
    ref.watch(loanLinkRepositoryProvider).watch();

/// The last 400 days of ledger rows (detection input, FR-12-01).
@riverpod
Stream<List<LedgerTx>> planWindow(Ref ref) {
  final from =
      DateTime.now().subtract(const Duration(days: 400)).millisecondsSinceEpoch;
  return ref
      .watch(transactionRepositoryProvider)
      .watch(LedgerFilter(fromMs: from), limit: 6000);
}

/// Loans plus dismissed payees (FR-15-01..04, FR-15-11).
class LoansState {
  /// Creates the state.
  const LoansState({required this.loans, required this.dismissed});

  /// Open and closed loans.
  final List<Loan> loans;

  /// Payees marked "Not a loan".
  final Set<String> dismissed;
}

/// Loans built from accounts, payments and links.
@riverpod
Future<LoansState> loansState(Ref ref) async {
  final book = await ref.watch(loanBookProvider.future);
  final links = await ref.watch(loanLinkSetProvider.future);
  final txs = await ref.watch(planWindowProvider.future);
  final now = DateTime.now().millisecondsSinceEpoch;
  final loans = Loans.build(
    accounts: book.loans,
    payments: txs,
    today: _today(now),
    dismissed: links.dismissed,
    links: LoanLinks(
      tx: links.tx,
      payee: links.payee,
      manualPayees: links.manualPayees,
    ),
    merged: book.merged,
  );
  return LoansState(loans: loans, dismissed: links.dismissed);
}

DateTime _today(int ms) => Ist.dateOf(ms);

/// Bills: detected plus user items plus loan EMIs (FR-12-01..06).
@riverpod
Future<List<Recurring>> bills(Ref ref) async {
  final txs = await ref.watch(planWindowProvider.future);
  final mine = await ref.watch(recurringItemsProvider.future);
  final loans = await ref.watch(loansStateProvider.future);
  final today = _today(DateTime.now().millisecondsSinceEpoch);
  final merged = RecurringDetector.withManual(
    RecurringDetector.detect(txs, today),
    mine,
    today,
  );
  return BillsView.withLoans(merged, loans.loans);
}

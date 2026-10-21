import 'package:hisaab/features/loans/domain/loan_models.dart';

/// Loan accounts plus every merged account, as the loan logic needs them.
class LoanBook {
  /// Creates a book.
  const LoanBook({this.loans = const [], this.merged = const []});

  /// Accounts of type LOAN that are not merged away.
  final List<LoanAccount> loans;

  /// Every account with a `mergedIntoId`.
  final List<LoanAccount> merged;
}

/// Input for a hand-entered loan (FR-15-06).
class LoanDraft {
  /// Creates a draft.
  const LoanDraft({
    required this.bankName,
    required this.principalMinor,
    required this.rateBps,
    required this.tenureMonths,
    this.last4,
    this.startDay,
    this.outstandingMinor,
  });

  /// Lender name.
  final String bankName;

  /// Four digits, or null to generate one.
  final String? last4;
  final int principalMinor;
  final int rateBps;
  final int tenureMonths;

  /// Epoch day of the first EMI.
  final int? startDay;

  /// Typed outstanding, kept as the manual balance.
  final int? outstandingMinor;
}

/// Reads and writes loan accounts (F-15). Terms live on the accounts row.
abstract interface class LoanAccountRepository {
  /// Live loan accounts and merged accounts.
  Stream<LoanBook> watch();

  /// Adds a loan account; null when (lender, last4) already exists.
  Future<int?> create(LoanDraft draft);

  /// Replaces the terms and balance of loan [id].
  Future<void> update(int id, LoanDraft draft);
}

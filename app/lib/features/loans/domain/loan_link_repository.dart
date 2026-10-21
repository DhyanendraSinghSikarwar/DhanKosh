/// Manual loan links and dismissals (F-15, FR-15-10, FR-15-11).
class LoanLinkSet {
  /// Creates a link set.
  const LoanLinkSet({
    this.tx = const {},
    this.payee = const {},
    this.manualPayees = const {},
    this.dismissed = const {},
  });

  /// txId -> loanId.
  final Map<int, int> tx;

  /// payeeKey -> loanId.
  final Map<String, int> payee;

  /// Payees the user linked by hand.
  final Set<String> manualPayees;

  /// Payees marked "Not a loan".
  final Set<String> dismissed;

  /// Lower-cased `merchant ?? upiId`, trimmed.
  static String keyOf(String? merchant, String? upiId) =>
      (merchant ?? upiId ?? '').trim().toLowerCase();
}

/// Stores loan links and dismissals.
abstract interface class LoanLinkRepository {
  /// Current links and dismissals.
  Future<LoanLinkSet> read();

  /// Live [read].
  Stream<LoanLinkSet> watch();

  /// Links a payment (FR-15-10).
  Future<void> linkTx(int txId, int loanId);

  /// Links a payee to a loan and marks it manual (FR-15-10).
  Future<void> linkPayee(String payeeKey, int loanId);

  /// Removes the tx link.
  Future<void> unlinkTx(int txId);

  /// Removes the payee link and its manual mark.
  Future<void> unlinkPayee(String payeeKey);

  /// "Not a loan": adds the payee to the dismissals (FR-15-11).
  Future<void> dismissPayee(String payeeKey);

  /// Removes a dismissal.
  Future<void> undismissPayee(String payeeKey);

  /// Drops every link to [loanId] (loan removed or merged away).
  Future<void> clearLoan(int loanId);
}

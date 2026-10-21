import 'package:drift/drift.dart';

/// Loan links: kind `tx` (key txId), `payee` (key payeeKey) or `manual`
/// (loanId null) (FR-15-10).
@DataClassName('LoanLinkRow')
class LoanLinkRows extends Table {
  TextColumn get kind => text()();
  TextColumn get key => text()();
  IntColumn get loanId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {kind, key};
}

/// Payees the user marked "Not a loan" (FR-15-11).
@DataClassName('LoanDismissalRow')
class LoanDismissalRows extends Table {
  TextColumn get payee => text()();

  @override
  Set<Column> get primaryKey => {payee};
}

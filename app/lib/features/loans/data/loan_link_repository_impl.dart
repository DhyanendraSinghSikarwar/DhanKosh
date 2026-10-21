import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/loans/domain/loan_link_repository.dart';

/// [LoanLinkRepository] over `loan_link_rows` and `loan_dismissal_rows`.
class LoanLinkRepositoryImpl implements LoanLinkRepository {
  /// Creates the repository.
  LoanLinkRepositoryImpl(this._db);

  final AppDatabase _db;

  Future<void> _put(String kind, String key, int? loanId) =>
      _db.into(_db.loanLinkRows).insertOnConflictUpdate(
            LoanLinkRowsCompanion.insert(
              kind: kind,
              key: key,
              loanId: Value(loanId),
            ),
          );

  Future<void> _del(String kind, String key) => (_db.delete(_db.loanLinkRows)
        ..where((t) => t.kind.equals(kind) & t.key.equals(key)))
      .go();

  @override
  Future<void> linkTx(int txId, int loanId) => _put('tx', '$txId', loanId);

  @override
  Future<void> linkPayee(String payeeKey, int loanId) =>
      _db.transaction(() async {
        await _put('payee', payeeKey, loanId);
        await _put('manual', payeeKey, null);
      });

  @override
  Future<void> unlinkTx(int txId) => _del('tx', '$txId');

  @override
  Future<void> unlinkPayee(String payeeKey) => _db.transaction(() async {
        await _del('payee', payeeKey);
        await _del('manual', payeeKey);
      });

  @override
  Future<void> dismissPayee(String payeeKey) =>
      _db.into(_db.loanDismissalRows).insertOnConflictUpdate(
            LoanDismissalRowsCompanion.insert(payee: payeeKey),
          );

  @override
  Future<void> undismissPayee(String payeeKey) => (_db.delete(
        _db.loanDismissalRows,
      )..where((t) => t.payee.equals(payeeKey)))
          .go();

  @override
  Future<void> clearLoan(int loanId) =>
      (_db.delete(_db.loanLinkRows)..where((t) => t.loanId.equals(loanId)))
          .go();

  Future<LoanLinkSet> _build() async {
    final links = await _db.select(_db.loanLinkRows).get();
    final dis = await _db.select(_db.loanDismissalRows).get();
    return LoanLinkSet(
      tx: {
        for (final r in links)
          if (r.kind == 'tx' && r.loanId != null && int.tryParse(r.key) != null)
            int.parse(r.key): r.loanId!,
      },
      payee: {
        for (final r in links)
          if (r.kind == 'payee' && r.loanId != null) r.key: r.loanId!,
      },
      manualPayees: {
        for (final r in links)
          if (r.kind == 'manual') r.key,
      },
      dismissed: {for (final r in dis) r.payee},
    );
  }

  @override
  Future<LoanLinkSet> read() => _build();

  @override
  Stream<LoanLinkSet> watch() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.loanLinkRows, _db.loanDismissalRows},
      )
      .watch()
      .asyncMap((_) => _build());
}

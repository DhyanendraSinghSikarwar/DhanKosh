import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/loans/domain/loan_account_repository.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:parser_core/parser_core.dart';

/// [LoanAccountRepository] over the `accounts` table.
class LoanAccountRepositoryImpl implements LoanAccountRepository {
  /// Creates the repository.
  LoanAccountRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  static LoanAccount _map(AccountRow r) => LoanAccount(
        id: r.id,
        bankName: r.bankName,
        last4: r.last4,
        nickname: r.nickname,
        hidden: r.hidden,
        principalMinor: r.loanPrincipalMinor,
        rateBps: r.loanRateBps,
        tenureMonths: r.loanTenureMonths,
        startDay: r.loanStartDay,
        currentBalanceMinor: r.manualBalanceMinor ?? r.latestBalanceMinor,
        latestBalanceMinor: r.latestBalanceMinor,
        balanceUpdatedAt: r.balanceUpdatedAt ?? r.manualBalanceAt,
        mergedIntoId: r.mergedIntoId,
      );

  @override
  Stream<LoanBook> watch() => _db.select(_db.accounts).watch().map((rows) {
        final loanType = enumToDb(AccountType.loan);
        return LoanBook(
          loans: [
            for (final r in rows)
              if (r.accountType == loanType && r.mergedIntoId == null) _map(r),
          ],
          merged: [
            for (final r in rows)
              if (r.mergedIntoId != null) _map(r),
          ],
        );
      });

  @override
  Future<int?> create(LoanDraft d) async {
    final last4 = d.last4 ?? (_now() % 10000).toString().padLeft(4, '0');
    final exists = await (_db.select(_db.accounts)
          ..where((t) => t.bankName.equals(d.bankName) & t.last4.equals(last4)))
        .getSingleOrNull();
    if (exists != null) return null;
    final now = _now();
    return _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            bankName: d.bankName,
            last4: last4,
            kind: enumToDb(AccountKind.account),
            createdAt: now,
            accountType: Value(enumToDb(AccountType.loan)),
            loanPrincipalMinor: Value(d.principalMinor),
            loanRateBps: Value(d.rateBps),
            loanTenureMonths: Value(d.tenureMonths),
            loanStartDay: Value(d.startDay),
            manualBalanceMinor: Value(d.outstandingMinor),
            manualBalanceAt: Value(d.outstandingMinor == null ? null : now),
          ),
        );
  }

  @override
  Future<void> update(int id, LoanDraft d) async {
    final now = _now();
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(
        bankName: Value(d.bankName),
        loanPrincipalMinor: Value(d.principalMinor),
        loanRateBps: Value(d.rateBps),
        loanTenureMonths: Value(d.tenureMonths),
        loanStartDay: Value(d.startDay),
        manualBalanceMinor: Value(d.outstandingMinor),
        manualBalanceAt: Value(d.outstandingMinor == null ? null : now),
      ),
    );
  }
}

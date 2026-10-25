import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart'
    show AccountType;
import 'package:hisaab/features/statement_import/domain/statement_account_store.dart';
import 'package:parser_core/parser_core.dart' show AccountKind;

/// [StatementAccountStore] over the `accounts` table (FR-05-07, FR-05-17).
/// Touches account figures only, never `transactions`.
class StatementAccountStoreImpl implements StatementAccountStore {
  /// Creates the store.
  StatementAccountStoreImpl(this._db, {int Function()? clock})
      : _now = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  @override
  Future<StatementAccount?> find(String bank, String last4) async {
    final r = await (_db.select(_db.accounts)
          ..where((t) => t.bankName.equals(bank) & t.last4.equals(last4)))
        .getSingleOrNull();
    if (r == null) return null;
    return StatementAccount(
      id: r.id,
      accountType: r.accountType == null
          ? null
          : enumFromDb(AccountType.values, r.accountType, AccountType.savings),
      balanceUpdatedAt: r.balanceUpdatedAt,
      loanPrincipalMinor: r.loanPrincipalMinor,
      maturityDay: r.maturityDay,
      maturityAction: r.maturityAction == null
          ? null
          : enumFromDb(
              DepositMaturityAction.values,
              r.maturityAction,
              DepositMaturityAction.credit,
            ),
    );
  }

  @override
  Future<int?> insert(
    String bank,
    String last4, {
    required AccountKind kind,
    AccountType? type,
  }) async {
    if (await find(bank, last4) != null) return null;
    return await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            bankName: bank,
            last4: last4,
            kind: enumToDb(kind),
            createdAt: _now(),
            accountType: Value(type == null ? null : enumToDb(type)),
          ),
        );
  }

  @override
  Future<void> setType(int id, AccountType type) =>
      (_db.update(_db.accounts)..where((t) => t.id.equals(id)))
          .write(AccountsCompanion(accountType: Value(enumToDb(type))));

  @override
  Future<void> setMaturity(
    int id,
    int? day,
    DepositMaturityAction? action,
  ) =>
      (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
        AccountsCompanion(
          maturityDay: Value(day),
          maturityAction: Value(action == null ? null : enumToDb(action)),
        ),
      );

  @override
  Future<void> setLoanPrincipal(int id, int principalMinor) =>
      (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
        AccountsCompanion(loanPrincipalMinor: Value(principalMinor)),
      );

  @override
  Future<void> hide(int id) =>
      (_db.update(_db.accounts)..where((t) => t.id.equals(id)))
          .write(const AccountsCompanion(hidden: Value(true)));

  @override
  Future<void> updateBalance(
    int id, {
    required int at,
    int? balanceMinor,
    int? limitMinor,
  }) async {
    if (balanceMinor == null && limitMinor == null) return;
    await _db.customUpdate(
      'UPDATE accounts SET '
      'latest_balance_minor = COALESCE(?, latest_balance_minor), '
      'available_limit_minor = COALESCE(?, available_limit_minor), '
      'balance_updated_at = ? '
      'WHERE id = ? AND (balance_updated_at IS NULL OR balance_updated_at <= ?)',
      variables: [
        Variable<int>(balanceMinor),
        Variable<int>(limitMinor),
        Variable<int>(at),
        Variable<int>(id),
        Variable<int>(at),
      ],
      updates: {_db.accounts},
    );
  }
}

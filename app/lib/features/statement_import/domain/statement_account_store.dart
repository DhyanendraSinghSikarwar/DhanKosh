import 'package:hisaab/features/accounts_management/domain/account.dart'
    show AccountType;
import 'package:parser_core/parser_core.dart' show AccountKind;

/// What a statement needs to know about an existing account.
class StatementAccount {
  /// Creates the view.
  const StatementAccount({
    required this.id,
    this.accountType,
    this.balanceUpdatedAt,
    this.maturityDay,
    this.maturityAction,
  });

  final int id;
  final AccountType? accountType;
  final int? balanceUpdatedAt;

  /// Epoch day.
  final int? maturityDay;
  final DepositMaturityAction? maturityAction;
}

/// What a bank does when a deposit matures.
enum DepositMaturityAction { credit, renewPrincipal, renewAll }

/// Account figures a statement sets, never transactions (FR-05-07, FR-05-17).
abstract interface class StatementAccountStore {
  /// Account of [bank] and [last4] (hidden ones too), or null.
  Future<StatementAccount?> find(String bank, String last4);

  /// Creates the account; null when it exists already.
  Future<int?> insert(
    String bank,
    String last4, {
    required AccountKind kind,
    AccountType? type,
  });

  /// Sets the account type.
  Future<void> setType(int id, AccountType type);

  /// Sets maturity day and action.
  Future<void> setMaturity(
    int id,
    int? day,
    DepositMaturityAction? action,
  );

  /// Hides the account (closed deposit).
  Future<void> hide(int id);

  /// Reported balance or card limit; applied only when [at] is not older
  /// than the last one (FR-13-07).
  Future<void> updateBalance(
    int id, {
    required int at,
    int? balanceMinor,
    int? limitMinor,
  });
}

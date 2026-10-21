import 'package:parser_core/parser_core.dart';

enum AccountType {
  savings,
  current,
  salary,
  nre,
  nro,
  wallet,
  fd,
  rd,
  ppf,
  loan,
  creditCard,
  debitCard,
  prepaidCard;

  /// FD, RD, PPF and loans do not count toward the Home balance.
  bool get liquid =>
      this != AccountType.fd &&
      this != AccountType.rd &&
      this != AccountType.ppf &&
      this != AccountType.loan;
}

enum CardNetwork {
  visa,
  mastercard,
  rupay,
  amex,
  diners,
  discover,
  jcb,
  maestro,
  unionpay,
}

enum AccountUsage { personal, business }

/// A bank account or card (FR-13). Money is paise; times are epoch ms.
class Account {
  const Account({
    required this.id,
    required this.bankName,
    required this.last4,
    required this.kind,
    required this.createdAt,
    this.nickname,
    this.colorArgb,
    this.latestBalanceMinor,
    this.availableLimitMinor,
    this.balanceUpdatedAt,
    this.manualBalanceMinor,
    this.manualBalanceAt,
    this.accountType,
    this.cardNetwork,
    this.linkedAccountId,
    this.hidden = false,
    this.usage = AccountUsage.personal,
    this.mergedIntoId,
  });

  final int id;
  final String bankName;
  final String last4;
  final AccountKind kind;
  final int createdAt;
  final String? nickname;
  final int? colorArgb;
  final int? latestBalanceMinor;
  final int? availableLimitMinor;
  final int? balanceUpdatedAt;
  final int? manualBalanceMinor;
  final int? manualBalanceAt;
  final AccountType? accountType;
  final CardNetwork? cardNetwork;
  final int? linkedAccountId;
  final bool hidden;
  final AccountUsage usage;
  final int? mergedIntoId;

  /// `nickname ?: "bank ••last4"`.
  String get label => nickname ?? '$bankName ••$last4';

  /// Counts toward the Home balance.
  bool get isLiquid =>
      kind == AccountKind.account &&
      (accountType?.liquid ?? true) &&
      !hidden &&
      mergedIntoId == null;

  bool get isDebitCard => accountType == AccountType.debitCard;
}

/// An account plus figures derived from the ledger (FR-13-07).
class AccountWithActivity {
  const AccountWithActivity({
    required this.account,
    required this.changeSinceManual,
    required this.changeSinceReported,
    required this.monthSpent,
    required this.transactionCount,
  });

  final Account account;
  final int changeSinceManual;
  final int changeSinceReported;
  final int monthSpent;
  final int transactionCount;

  int? get _reported => account.kind == AccountKind.card
      ? account.availableLimitMinor
      : account.latestBalanceMinor;

  /// Whether the typed balance is the base (typed newer than reported).
  bool get usesManual {
    final manual = account.manualBalanceMinor;
    final manualAt = account.manualBalanceAt;
    if (manual == null || manualAt == null) return false;
    final at = account.balanceUpdatedAt;
    return _reported == null || at == null || manualAt >= at;
  }

  /// Current balance (card: limit left), paise; null when nothing is known.
  int? get currentBalanceMinor {
    if (usesManual) return account.manualBalanceMinor! + changeSinceManual;
    final r = _reported;
    return r == null ? null : r + changeSinceReported;
  }

  /// True when a reported figure was moved by later transactions.
  bool get balanceIsEstimated =>
      !usesManual && changeSinceReported != 0 && _reported != null;
}

/// Input for adding an account by hand (FR-13-05).
class NewAccount {
  const NewAccount({
    required this.kind,
    required this.bankName,
    required this.last4,
    this.accountType,
    this.cardNetwork,
    this.balanceMinor,
    this.usage = AccountUsage.personal,
  });

  final AccountKind kind;
  final String bankName;
  final String last4;
  final AccountType? accountType;
  final CardNetwork? cardNetwork;

  /// Typed balance (card: available limit), stored as the manual balance.
  final int? balanceMinor;
  final AccountUsage usage;
}

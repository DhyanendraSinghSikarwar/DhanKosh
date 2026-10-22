import 'package:hisaab/features/accounts_management/domain/account.dart'
    show AccountType;
import 'package:hisaab/features/statement_import/domain/statement_account_store.dart';
import 'package:hisaab/features/statement_import/domain/statement_outcome.dart';
import 'package:parser_core/parser_core.dart' as pc;

/// Applies what a statement says to accounts, without writing transactions:
/// a card's available limit, a bank account's closing balance (FR-05-07) and
/// deposit accounts (FR-05-17). Only a newer figure replaces an older one.
class ApplyStatementAccounts {
  /// Creates the use case.
  const ApplyStatementAccounts(this._store);

  final StatementAccountStore _store;

  static const _istOffsetMs = 19800000;

  /// Statement date at 23:59 IST, epoch ms.
  static int endOfDayIst(pc.CivilDate d) =>
      d.toEpochDay() * 86400000 + (23 * 60 + 59) * 60000 - _istOffsetMs;

  /// Applies [r]'s totals to its account. [receivedAt] is the fallback time.
  Future<AccountEffect> applyTotals(
    pc.StatementResult r, {
    required int receivedAt,
  }) async {
    final s = r.summary;
    final bank = r.bankName;
    final last4 = r.last4;
    if (bank == null || last4 == null || r.deposits.isNotEmpty) {
      return AccountEffect.none;
    }
    final lastRowBalance = r.transactions
        .where((t) => t.balanceMinor != null)
        .map((t) => t.balanceMinor!)
        .lastOrNull;
    final closing = s.closingMinor ?? lastRowBalance;
    final card = r.kind == pc.AccountKind.card;
    final int? limit;
    if (card) {
      final avail = s.availableMinor;
      final cl = s.creditLimitMinor;
      limit =
          avail ?? (cl == null ? null : _floor0(cl - (s.totalDueMinor ?? 0)));
    } else {
      limit = null;
    }
    final figure = card ? limit : closing;
    if (figure == null) return AccountEffect.none;
    final at = s.statementDate != null
        ? endOfDayIst(s.statementDate!)
        : r.transactions.isNotEmpty
            ? r.transactions
                .map((t) => t.transactionTime)
                .reduce((a, b) => a > b ? a : b)
            : receivedAt;
    final existing = await _store.find(bank, last4);
    final id = existing?.id ??
        await _store.insert(bank, last4, kind: r.kind) ??
        (await _store.find(bank, last4))?.id;
    if (id == null) return AccountEffect.none;
    await _store.updateBalance(
      id,
      at: at,
      balanceMinor: card ? null : figure,
      limitMinor: card ? figure : null,
    );
    return AccountEffect(
      kind: card
          ? AccountEffectKind.availableLimit
          : AccountEffectKind.closingBalance,
      amountMinor: figure,
      bankName: bank,
      last4: last4,
    );
  }

  /// Applies deposit and loan statuses; returns how many accounts changed.
  Future<int> applyDeposits(List<pc.LoanStatus> statuses) async {
    var n = 0;
    for (final s in statuses) {
      final d = s.deposit;
      if (d != null) {
        if (await _deposit(s, d)) n++;
        continue;
      }
      final existing = await _store.find(s.lender, s.last4);
      final id = existing?.id ??
          await _store.insert(
            s.lender,
            s.last4,
            kind: pc.AccountKind.account,
            type: AccountType.loan,
          );
      if (id == null) continue;
      if (existing != null && existing.accountType == null) {
        await _store.setType(id, AccountType.loan);
      }
      await _store.updateBalance(
        id,
        at: s.at,
        balanceMinor: s.outstandingMinor,
      );
      n++;
    }
    return n;
  }

  Future<bool> _deposit(pc.LoanStatus s, pc.DepositInfo d) async {
    final type = switch (d.kind) {
      pc.DepositKind.fd => AccountType.fd,
      pc.DepositKind.rd => AccountType.rd,
      pc.DepositKind.ppf => AccountType.ppf,
    };
    final existing = await _store.find(s.lender, s.last4);
    final id = existing?.id ??
        await _store.insert(
          s.lender,
          s.last4,
          kind: pc.AccountKind.account,
          type: type,
        );
    if (id == null) return false;
    final t = existing?.accountType;
    if (existing != null && (t == null || t == AccountType.savings)) {
      await _store.setType(id, type);
    }
    final lastAt = existing?.balanceUpdatedAt;
    final newest = lastAt == null || s.at >= lastAt;
    final terms = _terms(d, s.at, existing, newest: newest);
    if (terms != null) await _store.setMaturity(id, terms.$1, terms.$2);
    if (d.closed && newest) await _store.hide(id);
    await _store.updateBalance(id, at: s.at, balanceMinor: s.outstandingMinor);
    return true;
  }

  /// Maturity day and action to save (Kotlin `DepositTerms.of`), or null.
  static (int?, DepositMaturityAction?)? _terms(
    pc.DepositInfo d,
    int at,
    StatementAccount? cur, {
    required bool newest,
  }) {
    final curDay = cur?.maturityDay;
    final curAction = cur?.maturityAction;
    if (d.closed) {
      if (!newest) return null;
      final day =
          d.maturity?.toEpochDay() ?? ((at + _istOffsetMs) / 86400000).floor();
      return (day, DepositMaturityAction.credit);
    }
    if (d.maturity == null && d.action == null) return null;
    if (!newest && curDay != null) return null;
    final day = d.maturity?.toEpochDay() ?? curDay;
    final action = switch (d.action) {
      pc.DepositAction.payout => DepositMaturityAction.credit,
      pc.DepositAction.renewPrincipal => DepositMaturityAction.renewPrincipal,
      pc.DepositAction.renewAll => DepositMaturityAction.renewAll,
      null => curAction,
    };
    if (day == curDay && action == curAction) return null;
    return (day, action);
  }

  static int _floor0(int v) => v < 0 ? 0 : v;
}

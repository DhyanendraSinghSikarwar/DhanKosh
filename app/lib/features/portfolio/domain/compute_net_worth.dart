import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:parser_core/parser_core.dart' show AccountKind;

/// Assets minus liabilities (FR-16-04, memory 16 section 10). Pure.
///
/// Assets: liquid bank balances > 0 (class cash), FD/RD (debt) and PPF
/// (retirement) deposit balances, and holdings by class (none in the business
/// book). A PPF deposit account is skipped when a PPF holding exists, so it
/// is not counted twice. Liabilities: loan balances (absolute) and card dues
/// (`owedMinor`), unless excluded. Personal book leaves out business
/// accounts.
NetWorth computeNetWorth({
  required List<AccountWithActivity> accounts,
  required List<Holding> holdings,
  required List<CardLimit> cards,
  NetWorthFilter filter = const NetWorthFilter(),
  Book book = Book.all,
}) {
  final parts = <WorthPart>[];
  var bank = 0;
  final deposit = <AssetClass, int>{};
  var loans = 0;
  final hasPpfHolding = holdings.any((h) => h.kind == HoldingKind.ppf);

  for (final a in accounts) {
    final acc = a.account;
    if (acc.kind != AccountKind.account ||
        acc.hidden ||
        acc.mergedIntoId != null) {
      continue;
    }
    if (filter.excludedAccountIds.contains(acc.id)) continue;
    if (book == Book.personal && acc.usage == AccountUsage.business) continue;
    final bal = a.currentBalanceMinor;
    if (bal == null) continue;
    switch (acc.accountType) {
      case AccountType.fd || AccountType.rd:
        if (bal > 0) {
          deposit.update(AssetClass.debt, (v) => v + bal, ifAbsent: () => bal);
        }
      case AccountType.ppf:
        if (bal > 0 && !hasPpfHolding) {
          deposit.update(
            AssetClass.retirement,
            (v) => v + bal,
            ifAbsent: () => bal,
          );
        }
      case AccountType.loan:
        if (!filter.excludedLiabilities.contains(LiabilityKind.loans)) {
          loans += bal.abs();
        }
      case _:
        if (acc.isLiquid && bal > 0) bank += bal;
    }
  }

  if (bank > 0 && !filter.excludedClasses.contains(AssetClass.cash)) {
    parts.add(
      WorthPart(
        key: 'bank',
        label: 'Bank',
        amountMinor: bank,
        liability: false,
        kind: PartKind.bank,
        assetClass: AssetClass.cash,
      ),
    );
  }
  deposit.forEach((cls, v) {
    if (!filter.excludedClasses.contains(cls)) {
      parts.add(
        WorthPart(
          key: 'deposit:${cls.name}',
          label: 'Deposits',
          amountMinor: v,
          liability: false,
          kind: PartKind.deposit,
          assetClass: cls,
        ),
      );
    }
  });

  if (book != Book.business) {
    final byClass = <AssetClass, int>{};
    for (final h in holdings) {
      final v = h.valueMinor;
      if (v == null || v <= 0) continue;
      if (filter.excludedClasses.contains(h.assetClass)) continue;
      byClass.update(h.assetClass, (x) => x + v, ifAbsent: () => v);
    }
    byClass.forEach((cls, v) {
      parts.add(
        WorthPart(
          key: 'holding:${cls.name}',
          label: cls.label,
          amountMinor: v,
          liability: false,
          kind: PartKind.holding,
          assetClass: cls,
        ),
      );
    });
  }

  if (loans > 0) {
    parts.add(
      WorthPart(
        key: 'loans',
        label: 'Loans',
        amountMinor: loans,
        liability: true,
        kind: PartKind.loan,
      ),
    );
  }
  if (!filter.excludedLiabilities.contains(LiabilityKind.cardDues)) {
    final due = cards
        .where((c) => !filter.excludedAccountIds.contains(c.id))
        .fold<int>(0, (s, c) => s + c.owedMinor);
    if (due > 0) {
      parts.add(
        WorthPart(
          key: 'card_dues',
          label: 'Card dues',
          amountMinor: due,
          liability: true,
          kind: PartKind.cardDue,
        ),
      );
    }
  }

  int sum({required bool liability}) => parts
      .where((p) => p.liability == liability)
      .fold(0, (s, p) => s + p.amountMinor);
  return NetWorth(
    assetsMinor: sum(liability: false),
    liabilitiesMinor: sum(liability: true),
    parts: parts,
    cards: cards,
  );
}

/// Whether today's point should be written (FR-16-05): the pair differs from
/// [today] and at least one side is positive.
bool shouldRecordWorth({
  required int assetsMinor,
  required int liabilitiesMinor,
  WorthPoint? today,
}) {
  if (assetsMinor <= 0 && liabilitiesMinor <= 0) return false;
  return today == null ||
      today.assetsMinor != assetsMinor ||
      today.liabilitiesMinor != liabilitiesMinor;
}

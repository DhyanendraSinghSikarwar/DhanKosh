import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/maturity_items.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_charts.dart';

WorthPart part(String l, int m, {bool debt = false}) => WorthPart(
      key: l,
      label: l,
      amountMinor: m,
      liability: debt,
      kind: debt ? PartKind.loan : PartKind.bank,
    );

Holding hold(
  int id,
  HoldingKind k,
  String n,
  int v, {
  int? prev,
}) =>
    Holding(
      id: id,
      kind: k,
      name: n,
      identifier: 'x$id',
      source: HoldingSource.manual,
      updatedAt: 0,
      valueMinor: v,
      previousValueMinor: prev,
    );

void main() {
  // FR-16-06 (B7)
  test('split by account groups, caps at 6 plus Others, skips debts', () {
    final parts = [
      for (var i = 1; i <= 8; i++) part('A$i', i * 100000),
      part('Home loan', 500000, debt: true),
      part('Empty', 0),
    ];
    final s = splitByAccount(parts);
    expect(s.length, 7);
    expect(s.first.label, 'A8');
    expect(s.last.label, 'Others');
    expect(s.last.amountMinor, (1 + 2) * 100000);
    final d = liabilityShares(parts);
    expect(d.single.label, 'Home loan');
    expect(d.single.amountMinor, 500000);
  });

  // FR-16-02 (B8)
  test('allocation by class and by holding inside a class', () {
    final hs = [
      hold(1, HoldingKind.stock, 'Alpha Ltd', 300000),
      hold(2, HoldingKind.mutualFund, 'Beta Fund', 700000),
      hold(3, HoldingKind.nps, 'NPS', 200000),
    ];
    final byClass = {
      AssetClass.equity: 1000000,
      AssetClass.retirement: 200000,
      AssetClass.cash: 50000,
    };
    final all = allocationShares(byClass, hs);
    expect(all.map((e) => e.label), ['Equity', 'Retirement', 'Cash']);
    final eq = allocationShares(byClass, hs, only: AssetClass.equity);
    expect(eq.map((e) => e.label), ['Beta Fund', 'Alpha Ltd']);
    expect(
      allocationShares(byClass, hs, only: AssetClass.cash).single.amountMinor,
      50000,
    );
    expect(allocationShares(byClass, hs, only: AssetClass.gold), isEmpty);
  });

  // B13
  test('holding spark needs a previous value', () {
    expect(
      holdingSpark(hold(1, HoldingKind.stock, 'A', 120000, prev: 100000)),
      [100000, 120000],
    );
    expect(holdingSpark(hold(2, HoldingKind.stock, 'B', 120000)), isEmpty);
  });

  // C10
  test('maturities group by month in date order', () {
    final base =
        DateTime.utc(2026, 11, 5).difference(DateTime.utc(1970)).inDays;
    MaturityItem m(String n, int day) => MaturityItem(
          accountId: 1,
          name: n,
          day: day,
          daysLeft: 10,
          soon: false,
          type: AccountType.fd,
        );
    final g = maturityByMonth([m('Later', base + 40), m('Soon', base)]);
    expect(g.keys, ['Nov 2026', 'Dec 2026']);
    expect(g['Nov 2026']!.single.name, 'Soon');
  });
}

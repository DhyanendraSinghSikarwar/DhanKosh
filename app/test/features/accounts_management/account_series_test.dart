import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account_series.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_estimate.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

LedgerTx _tx(int id, DateTime d, int amt, TransactionType type) => LedgerTx(
      id: id,
      amountMinor: amt,
      currency: 'INR',
      type: type,
      bankName: 'HDFC Bank',
      accountKind: AccountKind.account,
      channel: Channel.upi,
      timestamp: d.millisecondsSinceEpoch,
      hasExplicitTime: true,
      category: Category.other,
      transactionHash: 'h$id',
      confidence: 1,
      needsReview: false,
      createdAt: 0,
      inrMinor: amt,
    );

void main() {
  // TC-13-17 (FR-13-17)
  test('monthSeries sums spend and income, skips transfers', () {
    final now = DateTime(2026, 10, 27);
    final s = monthSeries(
      [
        _tx(1, DateTime(2026, 10, 3), 10000, TransactionType.debit),
        _tx(2, DateTime(2026, 10, 4), 5000, TransactionType.investment),
        _tx(3, DateTime(2026, 9, 4), 700000, TransactionType.credit),
        _tx(4, DateTime(2026, 9, 5), 999, TransactionType.transfer),
        _tx(5, DateTime(2025, 1, 5), 123, TransactionType.debit),
      ],
      SeriesRange.sixMonths,
      now,
    );
    expect(s, hasLength(6));
    expect(s.last.spentMinor, 15000);
    expect(s[4].incomeMinor, 700000);
    expect(s.fold<int>(0, (a, p) => a + p.spentMinor), 15000);
    final all = monthSeries(
      [_tx(5, DateTime(2025, 1, 5), 123, TransactionType.debit)],
      SeriesRange.allTime,
      now,
    );
    expect(all.first.year, 2025);
    expect(all.first.spentMinor, 123);
    expect(all, hasLength(22));
  });

  // FR-16-05 (A6)
  test('estimateWorthHistory walks balances back and keeps recorded points',
      () {
    final today = DateTime.utc(2026, 10, 27).millisecondsSinceEpoch ~/ 86400000;
    final sep30 = monthEndDay(2026, 9);
    final aug31 = monthEndDay(2026, 8);
    final pts = estimateWorthHistory(
      todayDay: today,
      accounts: [
        AccountFlow(
          balanceNowMinor: 5000000,
          effects: [
            FlowEffect(today - 3, -100000), // October spend
            FlowEffect(sep30 - 5, 800000), // September salary
          ],
        ),
      ],
      holdings: [HoldingValue(sep30, 1000000)],
      liabilitiesMinor: 20000,
      recorded: [WorthPoint(aug31, 1, 2)],
      months: 4,
    );
    expect(pts, hasLength(4));
    expect(pts.last.point.day, today);
    expect(pts.last.point.assetsMinor, 5000000 + 1000000);
    expect(pts.last.estimated, isTrue);
    // Sep 30: balance before October's spend.
    expect(pts[2].point.assetsMinor, 5000000 + 100000 + 1000000);
    // Aug 31: recorded wins and is not estimated.
    expect(pts[1].estimated, isFalse);
    expect(pts[1].point.assetsMinor, 1);
    // Jul 31: before the salary and the holding.
    expect(pts[0].point.assetsMinor, 5000000 + 100000 - 800000);
    expect(pts[0].point.liabilitiesMinor, 20000);
  });
}

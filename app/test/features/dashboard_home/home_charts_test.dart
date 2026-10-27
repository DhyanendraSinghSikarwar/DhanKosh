import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

int _n = 0;

LedgerTx tx(
  int day,
  int rupees,
  Category category, {
  String? sub,
  TransactionType type = TransactionType.debit,
}) {
  _n++;
  return LedgerTx(
    id: _n,
    amountMinor: rupees * 100,
    currency: 'INR',
    type: type,
    bankName: 'Test Bank',
    accountKind: AccountKind.account,
    channel: Channel.other,
    timestamp: DateTime(2026, 10, day, 12).millisecondsSinceEpoch,
    hasExplicitTime: true,
    category: category,
    subcategory: sub,
    transactionHash: 'h$_n',
    confidence: 1,
    needsReview: false,
    createdAt: 0,
  );
}

void main() {
  // FR-17-06 (B4)
  test('cumulative spend runs day by day in paise', () {
    final txs = [
      tx(1, 100, Category.food),
      tx(1, 50, Category.fuel),
      tx(3, 200, Category.shopping),
    ];
    expect(
      cumulativeSpend(txs, daysInMonth: 31, upToDay: 4),
      [15000, 15000, 35000, 35000],
    );
    expect(cumulativeSpend(txs, daysInMonth: 3).length, 3);
    expect(spentUpToDay(txs, 2), 15000);
    expect(spentUpToDay(txs, 31), 35000);
  });

  // FR-17-11 (B5)
  test('category slices: top 7 plus Others, percent of total', () {
    final cats = [
      Category.food,
      Category.groceries,
      Category.transport,
      Category.fuel,
      Category.shopping,
      Category.bills,
      Category.insurance,
      Category.entertainment,
      Category.health,
    ];
    final txs = [
      for (final (i, c) in cats.indexed) tx(2, 1000 - i * 100, c),
    ];
    final s = categorySlices(txs);
    expect(s.length, 8);
    expect(s.first.label, 'Food & Dining');
    expect(s.last.label, 'Others');
    expect(s.last.amountMinor, (300 + 200) * 100);
    final total = s.fold<int>(0, (a, e) => a + e.amountMinor);
    expect(total, 540000);
    expect(percentOf(s.first.amountMinor, total), 18);
  });

  test('credits and transfers are not spend', () {
    final s = categorySlices([
      tx(2, 500, Category.salary, type: TransactionType.credit),
      tx(2, 300, Category.transfer),
      tx(2, 100, Category.food),
    ]);
    expect(s.map((e) => e.label), ['Food & Dining']);
  });

  test('sub-category drill groups by subcategory', () {
    final s = subCategorySlices(
      [
        tx(2, 100, Category.food, sub: 'Swiggy'),
        tx(3, 50, Category.food, sub: 'Swiggy'),
        tx(4, 70, Category.food),
        tx(4, 900, Category.fuel),
      ],
      Category.food,
    );
    expect(s.map((e) => e.label), ['Swiggy', 'Other']);
    expect(s.first.amountMinor, 15000);
    expect(percentOf(0, 0), 0);
  });

  // FR-17-08 (B12)
  test('split bar shares sum to 1000 and cap at income', () {
    final b = splitBar(
      incomeMinor: 100000,
      spentMinor: 40000,
      investedMinor: 10000,
    );
    expect(b, (spent: 400, invested: 100, saved: 500));
    final over = splitBar(
      incomeMinor: 100000,
      spentMinor: 150000,
      investedMinor: 10000,
    );
    expect(over.spent + over.invested + over.saved, 1000);
    expect(over.saved, 0);
    expect(
      splitBar(incomeMinor: 0, spentMinor: 5, investedMinor: 0).saved,
      0,
    );
  });

  // FR-17-09
  test('upcoming rows: 0..7 days, soonest first, max 5', () {
    UpcomingRow r(String n, int d) => UpcomingRow(
          name: n,
          amountMinor: 100,
          days: d,
          kind: UpcomingKind.bill,
        );
    final rows = upcomingRows([
      for (var i = 0; i < 9; i++) r('b$i', 8 - i),
      r('late', -1),
    ]);
    expect(rows.map((e) => e.days), [0, 1, 2, 3, 4]);
    expect(upcomingWhen(0), 'Due today');
    expect(upcomingWhen(1), 'Tomorrow');
    expect(upcomingWhen(4), 'In 4 days');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/chart_data.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

var _n = 0;
LedgerTx _tx(
  DateTime day,
  int rupees,
  Category c, {
  String? sub,
  int hour = 13,
  AccountKind kind = AccountKind.account,
}) {
  _n++;
  return LedgerTx(
    id: _n,
    amountMinor: rupees * 100,
    currency: 'INR',
    type: TransactionType.debit,
    bankName: 'Test Bank',
    accountKind: kind,
    channel: Channel.other,
    timestamp: epochMsOf(day, hour: hour),
    hasExplicitTime: true,
    category: c,
    transactionHash: 'h$_n',
    confidence: 1,
    needsReview: false,
    createdAt: 0,
    subcategory: sub,
  );
}

void main() {
  final months = [
    DateTime.utc(2026, 8),
    DateTime.utc(2026, 9),
    DateTime.utc(2026, 10),
  ];
  final rows = [
    _tx(DateTime.utc(2026, 8, 3), 1000, Category.rent),
    _tx(DateTime.utc(2026, 9, 3), 2000, Category.food, sub: 'Cafe'),
    _tx(DateTime.utc(2026, 9, 4), 500, Category.food),
    _tx(DateTime.utc(2026, 10, 5), 700, Category.cash, hour: 7),
    _tx(
      DateTime.utc(2026, 10, 6),
      900,
      Category.shopping,
      kind: AccountKind.card,
    ),
  ];

  test('TC-37-02 stacked groups sum to the month total, average skips last',
      () {
    final flows = LedgerMath.monthly(rows, months);
    final bars = ChartData.stacked(flows);
    for (final (i, b) in bars.indexed) {
      // Category views include card purchases (ADR-0011).
      expect(
        b.total,
        flows[i].spent +
            ChartData.cardPurchases(
              rows.where((t) => dayOf(t.timestamp).month == b.month.month),
            ),
      );
    }
    expect(bars[1].lifestyle, 250000);
    expect(bars[0].essentials, 100000);
    expect(bars[2].other, 70000);
    expect(bars[2].lifestyle, 90000);
    expect(ChartData.averageExcludingLast(bars), (100000 + 250000) ~/ 2);
    expect(ChartData.averageExcludingLast(bars.take(1).toList()), 0);
  });

  test('TC-37-01 selection toggles, drills and goes back', () {
    var s = ChartSelection.none.tapCategory(Category.food);
    expect(s.category, Category.food);
    s = s.tapSub('Cafe');
    expect(s.subcategory, 'Cafe');
    s = s.tapSub('Cafe');
    expect(s.subcategory, isNull);
    s = s.tapSub('Cafe').back();
    expect(s.category, Category.food);
    expect(s.subcategory, isNull);
    expect(s.back().isEmpty, isTrue);
    expect(ChartSelection.none.tapCategory(Category.food).isEmpty, isFalse);
  });

  test('select filters by category, sub-category and heat cell', () {
    expect(
      ChartData.select(rows, const ChartSelection(category: Category.food))
          .length,
      2,
    );
    expect(
      ChartData.select(
        rows,
        const ChartSelection(category: Category.food, subcategory: 'Cafe'),
      ).length,
      1,
    );
    final cell = ChartData.heatCell(rows[3])!;
    final hit = ChartData.select(
      rows,
      ChartSelection.none.tapHeat(cell.$1, cell.$2),
    );
    expect(hit, contains(rows[3]));
    expect(hit.every((t) => ChartData.heatCell(t) == cell), isTrue);
    expect(
      ChartSelection.none.tapHeat(1, 2).tapHeat(1, 2).hasHeat,
      isFalse,
    );
  });

  test('sub-category and category-month series', () {
    expect(
      ChartData.subcategories(rows, Category.food),
      [('Cafe', 200000), ('Other', 50000)],
    );
    expect(
      ChartData.categoryMonthly(rows, Category.food, months).map((e) => e.$2),
      [0, 250000, 0],
    );
  });

  test('card purchases are visible beside the headline (ADR-0011)', () {
    expect(ChartData.cardPurchases(rows), 90000);
  });

  test('divergence is capped at +-1', () {
    const c = CategoryChange(
      category: Category.food,
      now: 300,
      before: 100,
      percent: 200,
    );
    const d = CategoryChange(
      category: Category.fuel,
      now: 50,
      before: 100,
      percent: -50,
    );
    expect(ChartData.divergence([c, d]), [1, -1]);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

var _n = 0;
int r(int rupees) => rupees * 100;

LedgerTx tx(
  DateTime day,
  int rupees,
  Category cat, {
  String? merchant,
  TransactionType type = TransactionType.debit,
  int hour = 12,
  bool explicitTime = true,
  String currency = 'INR',
  int? inrMinor,
  String bank = 'HDFC Bank',
  int minute = 0,
}) {
  _n++;
  return LedgerTx(
    id: _n,
    amountMinor: rupees * 100,
    currency: currency,
    type: type,
    bankName: bank,
    accountKind: AccountKind.account,
    channel: Channel.other,
    timestamp: epochMsOf(day, hour: hour, minute: minute),
    hasExplicitTime: explicitTime,
    category: cat,
    transactionHash: 'h$_n',
    confidence: 1,
    needsReview: false,
    createdAt: 0,
    merchant: merchant,
    inrMinor: inrMinor,
  );
}

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

void main() {
  group('LedgerMath (FR-18-18, FR-18-21)', () {
    test('rupees: inrMinor, INR amount, or zero for foreign without inr', () {
      expect(LedgerMath.rupees(tx(d(2026, 10, 1), 10, Category.food)), r(10));
      expect(
        LedgerMath.rupees(
          tx(
            d(2026, 10, 1),
            10,
            Category.food,
            currency: 'USD',
            inrMinor: 83000,
          ),
        ),
        83000,
      );
      expect(
        LedgerMath.rupees(
          tx(d(2026, 10, 1), 10, Category.food, currency: 'USD'),
        ),
        0,
      );
    });

    test('spend, income, invest definitions exclude transfers', () {
      final txs = [
        tx(d(2026, 10, 1), 100, Category.food),
        tx(d(2026, 10, 1), 500, Category.transfer),
        tx(d(2026, 10, 2), 1000, Category.salary, type: TransactionType.credit),
        tx(d(2026, 10, 2), 40, Category.refund, type: TransactionType.credit),
        tx(
          d(2026, 10, 2),
          900,
          Category.transfer,
          type: TransactionType.credit,
        ),
        tx(
          d(2026, 10, 3),
          200,
          Category.investment,
          type: TransactionType.investment,
        ),
      ];
      expect(LedgerMath.spent(txs), r(100));
      expect(LedgerMath.income(txs), r(1040)); // refunds count as income
      expect(LedgerMath.invested(txs), r(200));
    });

    test('groups map every category (FR-18-05)', () {
      expect(LedgerMath.group(Category.rent), SpendGroup.essentials);
      expect(LedgerMath.group(Category.fees), SpendGroup.essentials);
      expect(LedgerMath.group(Category.food), SpendGroup.lifestyle);
      expect(LedgerMath.group(Category.donations), SpendGroup.lifestyle);
      for (final c in [
        Category.other,
        Category.cash,
        Category.salary,
        Category.income,
        Category.refund,
        Category.transfer,
        Category.investment,
      ]) {
        expect(LedgerMath.group(c), SpendGroup.other);
      }
      expect(Category.values.length, 27);
    });

    test('byCategory sorted desc, zero sums dropped; byGroup totals', () {
      final txs = [
        tx(d(2026, 10, 1), 100, Category.food),
        tx(d(2026, 10, 2), 300, Category.rent),
        tx(d(2026, 10, 3), 50, Category.food),
        tx(d(2026, 10, 4), 10, Category.shopping, currency: 'USD'), // 0 rupees
      ];
      expect(
        LedgerMath.byCategory(txs),
        [(Category.rent, r(300)), (Category.food, r(150))],
      );
      final g = LedgerMath.byGroup(txs);
      expect(g[SpendGroup.essentials], r(300));
      expect(g[SpendGroup.lifestyle], r(150));
    });

    test('byMerchant: merchant ?? bank, most frequent category, top 6, 60 cap',
        () {
      final txs = [
        tx(d(2026, 10, 1), 100, Category.food, merchant: 'Swiggy'),
        tx(d(2026, 10, 2), 100, Category.food, merchant: 'Swiggy'),
        tx(d(2026, 10, 3), 100, Category.groceries, merchant: 'Swiggy'),
        tx(d(2026, 10, 4), 500, Category.fees),
        for (var i = 0; i < 7; i++)
          tx(d(2026, 10, 5 + i), 10 + i, Category.shopping, merchant: 'M$i'),
      ];
      final m = LedgerMath.byMerchant(txs);
      expect(m.first.name, 'HDFC Bank');
      expect(m[1].name, 'Swiggy');
      expect(m[1].total, r(300));
      expect(m[1].count, 3);
      expect(m[1].category, Category.food);
      expect(LedgerMath.topMerchants(txs).length, 6);
      final many = [
        for (var i = 0; i < 61; i++)
          tx(d(2026, 10, 1), 1, Category.food, merchant: 'Z', minute: i % 60),
      ];
      final p = LedgerMath.merchantPayments(many, 'Z');
      expect(p.payments.length, 60);
      expect(p.truncated, isTrue);
      expect(
        LedgerMath.merchantPayments(many.take(60), 'Z').truncated,
        isFalse,
      );
    });

    test('monthly buckets by IST month and cumulative per day', () {
      // 2026-09-30 20:00 UTC is 1 Oct 01:30 IST.
      final late = LedgerTx(
        id: 999,
        amountMinor: r(100),
        currency: 'INR',
        type: TransactionType.debit,
        bankName: 'B',
        accountKind: AccountKind.account,
        channel: Channel.other,
        timestamp: DateTime.utc(2026, 9, 30, 20).millisecondsSinceEpoch,
        hasExplicitTime: true,
        category: Category.food,
        transactionHash: 'x',
        confidence: 1,
        needsReview: false,
        createdAt: 0,
      );
      final txs = [
        late,
        tx(d(2026, 10, 1), 50, Category.food),
        tx(d(2026, 9, 29), 7, Category.rent),
      ];
      final m = LedgerMath.monthly(txs, [d(2026, 9, 1), d(2026, 10, 1)]);
      expect(m[0].spent, r(7));
      expect(m[1].spent, r(150));
      final cum = LedgerMath.cumulative(txs, d(2026, 10, 1));
      expect(cum.length, 31);
      expect(cum[0], r(150));
      expect(cum.last, r(150));
    });

    test('heat grid: weekday rows Monday first, 3-hour slots from 6a', () {
      // 2026-10-19 is a Monday.
      final txs = [
        tx(d(2026, 10, 19), 100, Category.food, hour: 6),
        tx(d(2026, 10, 19), 20, Category.food, hour: 8, minute: 59),
        tx(d(2026, 10, 19), 7, Category.food, hour: 9),
        tx(d(2026, 10, 25), 5, Category.food, hour: 3), // Sunday 3am -> slot 7
        tx(
          d(2026, 10, 20),
          50,
          Category.food,
          hour: 0,
        ), // Tuesday midnight -> slot 6
        tx(d(2026, 10, 20), 999, Category.food, explicitTime: false),
      ];
      final g = LedgerMath.heat(txs);
      expect(g[0][0], r(120));
      expect(g[0][1], r(7));
      expect(g[6][7], r(5));
      expect(g[1][6], r(50));
      expect(g[1][2], 0); // untimed row ignored
      expect(LedgerMath.dayLabels.first, 'Mon');
    });

    test('heat peak widens to neighbours within 60% of the peak', () {
      final grid = [for (var i = 0; i < 7; i++) List<int>.filled(8, 0)];
      grid[0][4] = 60;
      grid[1][4] = 100;
      grid[2][4] = 59;
      grid[3][4] = 61;
      var p = LedgerMath.heatPeak(grid)!;
      expect([p.firstDay, p.lastDay, p.slot, p.peakDay], [0, 1, 4, 1]);
      expect(LedgerMath.peakText(p), 'Mon–Tue, 6p–9p');
      grid[2][4] = 60;
      p = LedgerMath.heatPeak(grid)!;
      expect([p.firstDay, p.lastDay], [0, 3]);
      expect(
        LedgerMath.heatPeak(
          [for (var i = 0; i < 7; i++) List<int>.filled(8, 0)],
        ),
        isNull,
      );
      grid[1][4] = 0;
      grid[0][4] = 0;
      grid[2][4] = 0;
      grid[3][4] = 0;
      grid[6][7] = 1;
      expect(LedgerMath.peakText(LedgerMath.heatPeak(grid)!), 'Sun, 3a–6a');
    });

    test('top category of a heat cell; weekly and daily buckets', () {
      final txs = [
        tx(d(2026, 10, 19), 100, Category.food, hour: 7),
        tx(d(2026, 10, 19), 300, Category.shopping, hour: 8),
        tx(d(2026, 10, 25), 50, Category.food), // Sunday, same ISO week
        tx(d(2026, 10, 26), 20, Category.food), // next Monday
      ];
      expect(LedgerMath.topCategoryInCell(txs, 0, 0), Category.shopping);
      expect(LedgerMath.topCategoryInCell(txs, 3, 0), isNull);
      final w = LedgerMath.weekly(txs);
      expect(w, [(d(2026, 10, 19), r(450)), (d(2026, 10, 26), r(20))]);
      expect(LedgerMath.daily(txs)[d(2026, 10, 19)], r(400));
    });

    test('monthly card average excludes the running month; month sheet percent',
        () {
      MonthFlow mf(int spent) => MonthFlow(
            month: d(2026, 1, 1),
            spent: spent,
            income: 0,
            invested: 0,
            byGroup: const {},
          );
      final months = [mf(100), mf(200), mf(300), mf(1000)];
      expect(LedgerMath.averageExcludingLast(months), 200);
      // Mean of the other three is 200: 1000 is 400% above.
      expect(LedgerMath.monthVsAverage(months, 3), 400);
      // Mean of the others (200, 300, 1000) is 500: 100 is 80% below.
      expect(LedgerMath.monthVsAverage(months, 0), -80);
      expect(LedgerMath.monthVsAverage([mf(5)], 0), isNull);
      expect(LedgerMath.averageExcludingLast([mf(5)]), 0);
    });
  });

  group('AnalyticsMath.build (FR-18-03, 09..11, 16)', () {
    final today = d(2026, 10, 17);
    final months = [
      for (var m = 11; m <= 12; m++) d(2025, m, 1),
      for (var m = 1; m <= 10; m++) d(2026, m, 1),
    ];

    AnalyticsSlice slice(
      List<LedgerTx> cur,
      List<LedgerTx> prev, {
      List<LedgerTx>? year,
      List<CashAccount> accounts = const [],
      AnalyticsPeriodKind kind = AnalyticsPeriodKind.month,
      DateTime? from,
      DateTime? to,
    }) =>
        AnalyticsSlice(
          txs: cur,
          previous: prev,
          year: year ?? [...prev, ...cur],
          months: months,
          from: from ?? d(2026, 10, 1),
          to: to ?? d(2026, 10, 31),
          kind: kind,
          month: d(2026, 10, 1),
          previousFrom: d(2026, 9, 1),
          previousTo: d(2026, 9, 30),
          accounts: accounts,
        );

    AnalyticsData build(
      AnalyticsSlice s, {
      PlanSnapshot plan = const PlanSnapshot(),
      List<Budget> budgets = const [],
      int alert = 90,
      DateTime? now,
    }) =>
        AnalyticsMath.build(
          slice: s,
          plan: plan,
          budgets: budgets,
          alertPercent: alert,
          today: now ?? today,
        );

    test('KPIs, per day, income buckets and classification (FR-18-10)', () {
      final cur = [
        tx(d(2026, 10, 1), 17000, Category.rent),
        tx(d(2026, 10, 5), 3400, Category.food),
        tx(
          d(2026, 10, 2),
          100000,
          Category.salary,
          type: TransactionType.credit,
        ),
        tx(d(2026, 10, 3), 500, Category.refund, type: TransactionType.credit),
        tx(
          d(2026, 10, 4),
          300,
          Category.income,
          type: TransactionType.credit,
          merchant: 'FD Interest',
        ),
        tx(
          d(2026, 10, 5),
          7000,
          Category.income,
          type: TransactionType.credit,
          merchant: 'Freelance',
        ),
        tx(
          d(2026, 10, 6),
          9000,
          Category.transfer,
          type: TransactionType.credit,
        ),
        tx(
          d(2026, 10, 7),
          2000,
          Category.investment,
          type: TransactionType.investment,
        ),
      ];
      final a = build(slice(cur, const []));
      expect(a.spent, r(20400));
      expect(a.income, r(107800));
      expect(a.invested, r(2000));
      expect(a.perDay, r(20400) ~/ 17); // Oct 1..17
      expect(a.salary, r(100000));
      expect(a.refunds, r(800)); // refund + "interest" merchant
      expect(a.otherIncome, r(7000));
      expect(a.savedOrOver, r(107800 - 20400));
      expect(a.categories.first, (Category.rent, r(17000)));
      expect(a.isCurrentMonth, isTrue);
      expect(a.loaded, isTrue);
      final sk = AnalyticsMath.sankey(a);
      expect(sk.saved, r(107800 - 20400 - 2000));
      expect(
        sk.outputs.map((e) => e.label),
        ['Essentials', 'Lifestyle', 'Other', 'Invested', 'Saved'],
      );
      expect(sk.outputs[0].value, r(17000));
      expect(sk.outputs[1].value, r(3400));
      expect(sk.isShortfall, isFalse);
    });

    test('not loaded gives an empty data; past period has no forecast or cash',
        () {
      expect(
        AnalyticsMath.build(
          slice: AnalyticsSlice(
            txs: const [],
            previous: const [],
            year: const [],
            months: const [],
            from: today,
            to: today,
            kind: AnalyticsPeriodKind.other,
            loaded: false,
          ),
          plan: const PlanSnapshot(),
          budgets: const [],
          alertPercent: 90,
          today: today,
        ).loaded,
        isFalse,
      );
      final a = build(
        slice(const [], const [], kind: AnalyticsPeriodKind.lastMonth),
        now: d(2026, 11, 3),
      );
      expect(a.isCurrentMonth, isFalse);
      expect(a.forecast, isNull);
      expect(a.cash, isNull);
    });

    test('per-day uses days up to today, at least 1', () {
      final a = build(
        slice([tx(d(2026, 10, 1), 100, Category.food)], const []),
        now: d(2026, 10, 1),
      );
      expect(a.perDay, r(100));
      final b = build(
        slice(
          [tx(d(2026, 10, 1), 100, Category.food)],
          const [],
          from: d(2026, 11, 1),
          to: d(2026, 11, 30),
        ),
        now: d(2026, 10, 1),
      );
      expect(b.perDay, r(100)); // days clamps to 1
    });

    test('shortfall sankey: saved clamps at zero', () {
      final a = build(
        slice(
          [
            tx(d(2026, 10, 1), 500, Category.food),
            tx(
              d(2026, 10, 2),
              100,
              Category.salary,
              type: TransactionType.credit,
            ),
          ],
          const [],
        ),
      );
      final sk = AnalyticsMath.sankey(a);
      expect(sk.saved, -r(400));
      expect(sk.isShortfall, isTrue);
      expect(sk.leftOver, r(400));
      expect(sk.outputs.last.value, 0);
    });

    test('compare: percent rules, ordering and labels (FR-18-16)', () {
      final cur = [
        tx(d(2026, 10, 1), 150, Category.food),
        tx(d(2026, 10, 2), 40, Category.fuel),
        tx(d(2026, 10, 3), 5000, Category.shopping),
      ];
      final prev = [
        tx(d(2026, 9, 1), 100, Category.food),
        tx(d(2026, 9, 2), 70, Category.travel),
        tx(d(2026, 9, 3), 5000, Category.shopping),
      ];
      final a = build(slice(cur, prev));
      final byCat = {for (final c in a.changes) c.category: c};
      expect(byCat[Category.food]!.percent, 50);
      expect(byCat[Category.fuel]!.percent, 100); // new
      expect(byCat[Category.travel]!.percent, -100); // stopped
      expect(byCat[Category.shopping]!.percent, 0);
      expect(a.changes.first.category, Category.travel); // |70| largest diff
      expect(
        a.changes.map((c) => (c.now - c.before).abs()).toList(),
        [for (final x in a.changes) (x.now - x.before).abs()]
          ..sort((x, y) => y.compareTo(x)),
      );
      expect(a.previousSpent, r(5170));
      expect(a.change, a.spent - a.previousSpent);
      expect(a.previousLabel, 'Sep 2026');
      expect(byCat[Category.food]!.barPercent, 50);
      final big = build(
        slice(
          [tx(d(2026, 10, 1), 1000, Category.food)],
          [tx(d(2026, 9, 1), 1, Category.food)],
        ),
      );
      expect(big.changes.single.percent, 999); // clamped
      expect(big.changes.single.barPercent, 50);
      final custom = AnalyticsSlice(
        txs: const [],
        previous: const [],
        year: const [],
        months: months,
        from: d(2026, 10, 1),
        to: d(2026, 10, 10),
        kind: AnalyticsPeriodKind.custom,
        previousFrom: d(2026, 9, 21),
        previousTo: d(2026, 9, 30),
      );
      expect(build(custom).previousLabel, '21 Sep – 30 Sep');
    });

    test(
        'savings rate: months with income, clamp, summary needs two (FR-18-11)',
        () {
      MonthFlow mf(int m, int income, int spent) => MonthFlow(
            month: d(2026, m, 1),
            spent: spent,
            income: income,
            invested: 0,
            byGroup: const {},
          );
      final rates = AnalyticsMath.savingsRates(
        [mf(1, 100, 50), mf(2, 0, 10), mf(3, 100, 300), mf(4, 200, 150)],
      );
      expect(rates.map((e) => e.$2), [50, -100, 25]);
      expect(AnalyticsMath.savingsSummary(rates.take(1).toList()), isNull);
      final s = AnalyticsMath.savingsSummary(rates)!;
      expect(s.months, 3);
      expect(s.latestPercent, 25);
      expect(s.averagePercent, -8); // (50 - 100 + 25) / 3 = -8.33
      expect(s.latestMonth, d(2026, 4, 1));
      final half = AnalyticsMath.savingsSummary(
        [(d(2026, 1, 1), 12.5), (d(2026, 2, 1), 12.5)],
      )!;
      expect(half.averagePercent, 13); // rounds half up
    });

    test(
        'budgets: limit x months, pace only for the current single month, fallback percent',
        () {
      final budgets = [
        Budget(category: Category.food, monthlyLimitMinor: r(10000)),
        Budget(category: Category.fuel, monthlyLimitMinor: r(5000)),
        const Budget(category: Category.rent, monthlyLimitMinor: 0),
      ];
      final cur = [
        tx(d(2026, 10, 1), 9000, Category.food),
        tx(d(2026, 10, 2), 1000, Category.fuel),
      ];
      final a = build(slice(cur, const []), budgets: budgets, alert: 0);
      final b = a.budgets!;
      expect(a.budget, r(15000));
      expect(b.lines.map((l) => l.category), [Category.food, Category.fuel]);
      expect(b.lines.first.limitMinor, r(10000));
      expect(b.alertPercent, 90);
      expect(b.pace, closeTo(17 / 31, 1e-9));
      final quarter = AnalyticsSlice(
        txs: cur,
        previous: const [],
        year: cur,
        months: months,
        from: d(2026, 8, 1),
        to: d(2026, 10, 31),
        kind: AnalyticsPeriodKind.custom,
      );
      final q = build(quarter, budgets: budgets, alert: 95).budgets!;
      expect(q.months, 3);
      expect(q.lines.first.limitMinor, r(30000));
      expect(q.pace, isNull);
      expect(q.alertPercent, 95);
    });
  });

  group('forecast and cash (FR-18-13..15, worked example)', () {
    final today = d(2026, 10, 17);

    test('discretionary rate: 3-month blend of the memory worked example', () {
      final txs = <LedgerTx>[
        tx(d(2026, 7, 10), 46000, Category.shopping),
        tx(d(2026, 8, 10), 46000, Category.food),
        tx(d(2026, 9, 10), 46000, Category.food),
        tx(d(2026, 9, 11), 99999, Category.rent), // fixed: excluded
        tx(d(2026, 10, 10), 27200, Category.food),
      ];
      // prior = Jul 31 + Aug 31 + Sep 30 = 92 days, Rs 1,38,000 -> 150,000 paise/day.
      expect(
        AnalyticsMath.discretionaryRate(txs, today),
        (13800000 ~/ 92 + 2720000 ~/ 17) ~/ 2,
      );
      expect(13800000 ~/ 92, 150000);
      expect(2720000 ~/ 17, 160000);
      expect(AnalyticsMath.discretionaryRate(txs, today), 155000);
    });

    test('rate edge cases: no prior months, day < 7, empty', () {
      final cur = [tx(d(2026, 10, 3), 600, Category.food)];
      expect(
        AnalyticsMath.discretionaryRate(cur, d(2026, 10, 10)),
        r(600) ~/ 10,
      );
      final prior = [
        tx(d(2026, 9, 3), 3000, Category.food),
        tx(d(2026, 10, 3), 600, Category.food),
      ];
      expect(
        AnalyticsMath.discretionaryRate(prior, d(2026, 10, 6)),
        r(3000) ~/ 30,
      );
      expect(AnalyticsMath.discretionaryRate(const [], today), 0);
      // Only months with spend count among the prior three.
      expect(
        AnalyticsMath.discretionaryRate(
          [tx(d(2026, 6, 3), 1, Category.food)],
          today,
        ),
        0,
      );
    });

    test('worked example: expected, low and high month-end', () {
      final txs = [tx(d(2026, 10, 3), 60000, Category.shopping)];
      final plan = PlanSnapshot(
        upcoming: [
          UpcomingItem(
            kind: UpcomingKind.bill,
            due: d(2026, 10, 25),
            amountMinor: r(12000),
          ),
          UpcomingItem(
            kind: UpcomingKind.bill,
            due: d(2026, 10, 28),
            amountMinor: r(649),
          ),
          UpcomingItem(
            kind: UpcomingKind.income,
            due: d(2026, 10, 30),
            amountMinor: r(5000),
          ),
          UpcomingItem(
            kind: UpcomingKind.bill,
            due: d(2026, 11, 2),
            amountMinor: r(1),
          ),
          UpcomingItem(
            kind: UpcomingKind.bill,
            due: d(2026, 10, 16),
            amountMinor: r(1),
          ),
        ],
      );
      final f = AnalyticsMath.forecast(txs, plan, 155000, today);
      expect(f.actual.length, 17);
      expect(f.expected.length, 15); // remaining 14 + index 0
      expect(f.expected.first, r(60000));
      expect(f.likely, 6000000 + 1264900 + 155000 * 14); // 9,434,900
      expect(f.likely, 9434900);
      expect(f.lowEnd, 9000900);
      expect(f.highEnd, 9868900);
      expect(f.billsLeft, 1264900);
      expect(
        f.expected[8],
        6000000 + 1200000 + 155000 * 8,
      ); // 25th included at i=8
      expect(f.expected[7], 6000000 + 155000 * 7);
    });

    test('verdict against the budget (FR-18-13)', () {
      final f =
          AnalyticsMath.forecast(const [], const PlanSnapshot(), 100, today);
      expect(f.verdict(0).kind, ForecastVerdictKind.noBudget);
      expect(f.verdict(f.likely).kind, ForecastVerdictKind.within);
      final over = f.verdict(f.likely - 1);
      expect(over.kind, ForecastVerdictKind.over);
      expect(over.overBy, 1);
    });

    AnalyticsSlice withAccounts(List<CashAccount> a) => AnalyticsSlice(
          txs: const [],
          previous: const [],
          year: const [],
          months: const [],
          from: d(2026, 10, 1),
          to: d(2026, 10, 31),
          kind: AnalyticsPeriodKind.month,
          month: d(2026, 10, 1),
          accounts: a,
        );

    test('cash projection: bills, incomes, daily rate, lowest and shortfall',
        () {
      final plan = PlanSnapshot(
        recurring: [
          PlannedPayment(
            name: 'Rent',
            amountMinor: r(20000),
            category: Category.rent,
            nextDue: d(2026, 10, 20),
            accountId: 1,
          ),
          PlannedPayment(
            name: 'Salary',
            amountMinor: r(50000),
            category: Category.salary,
            nextDue: d(2026, 11, 1),
            income: true,
          ),
          PlannedPayment(
            name: 'Card charge',
            amountMinor: r(999),
            category: Category.shopping,
            nextDue: d(2026, 10, 18),
            accountId: 2,
          ),
          PlannedPayment(
            name: 'Yearly',
            amountMinor: r(100),
            category: Category.bills,
            nextDue: d(2026, 10, 18),
            yearly: true,
          ),
        ],
        upcoming: [
          UpcomingItem(
            kind: UpcomingKind.insurance,
            due: d(2026, 10, 19),
            amountMinor: r(12000),
          ),
        ],
      );
      final accts = [
        const CashAccount(id: 1, isLiquid: true, balanceMinor: 3000000),
        const CashAccount(id: 2, isLiquid: false, isCard: true),
        const CashAccount(id: 3, isLiquid: true, balanceMinor: 500000),
        const CashAccount(id: 4, isLiquid: false, balanceMinor: 99999999),
      ];
      final c = AnalyticsMath.cash(withAccounts(accts), plan, 10000, today)!;
      expect(c.start, 3500000);
      expect(c.series.length, 31);
      expect(c.series[0], 3500000);
      expect(c.series[1], 3500000 - 10000 - r(100)); // yearly bill on the 18th
      expect(
        c.series[2],
        c.series[1] - 10000 - r(12000),
      ); // insurance on the 19th
      expect(c.series[3], c.series[2] - 10000 - r(20000)); // rent on the 20th
      expect(c.bills, 3); // yearly, insurance, rent (card charge skipped)
      expect(c.incomes, 1); // salary on 1 Nov (day 15)
      expect(c.series[15], c.series[14] - 10000 + r(50000));
      expect(c.lowest, c.series.reduce((a, b) => a < b ? a : b));
      expect(c.lowestOn, today.add(Duration(days: c.series.indexOf(c.lowest))));
      expect(c.shortfall, c.lowest < 0);
    });

    test(
        'cash: monthly items repeat within 30 days; none without a liquid balance',
        () {
      final plan = PlanSnapshot(
        recurring: [
          PlannedPayment(
            name: 'Gym',
            amountMinor: r(1000),
            category: Category.health,
            nextDue: d(2026, 10, 18),
          ),
        ],
      );
      final c = AnalyticsMath.cash(
        withAccounts(
          [const CashAccount(id: 1, isLiquid: true, balanceMinor: 100)],
        ),
        plan,
        0,
        today,
      )!;
      expect(c.bills, 1); // 18 Oct; 18 Nov is day 32
      expect(c.shortfall, isTrue);
      expect(c.lowest, 100 - r(1000));
      expect(c.lowestOn, d(2026, 10, 18));
      expect(
        AnalyticsMath.cash(withAccounts(const []), plan, 0, today),
        isNull,
      );
      expect(
        AnalyticsMath.cash(
          withAccounts([const CashAccount(id: 1, isLiquid: true)]),
          plan,
          0,
          today,
        ),
        isNull,
      );
      // A debit-card charge counts; a due-today item lands on day 1.
      final plan2 = PlanSnapshot(
        recurring: [
          PlannedPayment(
            name: 'X',
            amountMinor: 5,
            category: Category.bills,
            nextDue: today,
            accountId: 9,
          ),
        ],
      );
      final c2 = AnalyticsMath.cash(
        withAccounts([
          const CashAccount(id: 1, isLiquid: true, balanceMinor: 100),
          const CashAccount(
            id: 9,
            isLiquid: false,
            isCard: true,
            isDebitCard: true,
          ),
        ]),
        plan2,
        0,
        today,
      )!;
      expect(c2.series[1], 95);
    });
  });

  group('insights (FR-18-17)', () {
    final today = d(2026, 10, 17); // Saturday

    test('pace ahead of last month (port of Kotlin PlanningTest)', () {
      final txs = [
        tx(d(2026, 9, 10), 2000, Category.food, merchant: 'Swiggy'),
        tx(d(2026, 10, 10), 6000, Category.food, merchant: 'Swiggy'),
      ];
      final i = AnalyticsMath.insights(txs, const [], today);
      final pace = i.first;
      expect(pace.title, 'Spending is 200% ahead of last month');
      expect(pace.tone, Tone.warn);
      expect(
        pace.detail,
        "By day 17 you've spent ₹6,000, against ₹2,000 by this day last month.",
      );
    });

    test(
        'pace below last month is GOOD; under 10% is silent; boundary 10 fires',
        () {
      List<Insight> run(int now, int last) => AnalyticsMath.insights(
            [
              tx(d(2026, 9, 10), last, Category.food),
              tx(d(2026, 10, 10), now, Category.food),
            ],
            const [],
            today,
          );
      expect(run(50, 100).first.title, 'Spending is 50% below last month');
      expect(run(50, 100).first.tone, Tone.good);
      expect(
        run(109, 100).where((e) => e.title.startsWith('Spending')),
        isEmpty,
      );
      expect(run(110, 100).first.title, 'Spending is 10% ahead of last month');
    });

    test('category drift needs 500 rupees above the 3-month average', () {
      final prior = [
        for (final m in [7, 8, 9]) tx(d(2026, m, 10), 3000, Category.food),
      ];
      List<Insight> run(int now) => AnalyticsMath.insights(
            [...prior, tx(d(2026, 10, 10), now, Category.food)],
            const [],
            today,
          );
      expect(
        run(3499).where((e) => e.title.contains('above your usual')),
        isEmpty,
      );
      final hit =
          run(3500).firstWhere((e) => e.title.contains('above your usual'));
      expect(hit.title, 'Food & Dining is above your usual');
      expect(
        hit.detail,
        '₹3,500 so far this month against a 3-month average of ₹1,000.'
            .replaceAll('₹1,000', '₹3,000'),
      );
      expect(hit.tone, Tone.warn);
    });

    test('regular payments, biggest expense and weekend share', () {
      final rec = [
        PlannedPayment(
          name: 'Netflix',
          amountMinor: r(649),
          category: Category.subscriptions,
          nextDue: today,
        ),
        PlannedPayment(
          name: 'Rent',
          amountMinor: r(20000),
          category: Category.rent,
          nextDue: today,
        ),
        PlannedPayment(
          name: 'Salary',
          amountMinor: r(90000),
          category: Category.salary,
          nextDue: today,
          income: true,
        ),
      ];
      final txs = [
        tx(
          d(2026, 10, 10),
          1000,
          Category.food,
          merchant: 'Swiggy',
        ), // Saturday
        tx(d(2026, 10, 12), 900, Category.shopping), // Monday
      ];
      final out = AnalyticsMath.insights(txs, rec, today);
      final titles = out.map((e) => e.title).toList();
      expect(titles, [
        '2 regular payments, ₹20,649 a month',
        'Biggest expense: ₹1,000',
        '52% of spending is on weekends',
      ]);
      expect(out[0].detail, 'Including 1 subscription and bills worth ₹649.');
      expect(out[1].detail, 'Swiggy on 10 Oct.');
      expect(
        AnalyticsMath.insights(txs, [rec[1]], today).first.detail,
        'Rent, EMIs, SIPs and premiums that come every month.',
      );
      expect(
        AnalyticsMath.insights(txs, [rec[0], rec[0]], today).first.detail,
        'Including 2 subscriptions and bills worth ₹1,298.',
      );
      final lowWeekend = AnalyticsMath.insights(
        [
          tx(d(2026, 10, 10), 44, Category.food),
          tx(d(2026, 10, 12), 56, Category.food),
        ],
        const [],
        today,
      );
      expect(lowWeekend.where((e) => e.title.contains('weekends')), isEmpty);
      expect(
        AnalyticsMath.insights(
          [
            tx(d(2026, 10, 10), 45, Category.food),
            tx(d(2026, 10, 12), 55, Category.food),
          ],
          const [],
          today,
        ).any((e) => e.title == '45% of spending is on weekends'),
        isTrue,
      );
    });

    test('max caps the list; review, foreign and credit rows are ignored', () {
      final rec = [
        PlannedPayment(
          name: 'Netflix',
          amountMinor: 100,
          category: Category.subscriptions,
          nextDue: today,
        ),
      ];
      final txs = [
        tx(d(2026, 10, 10), 1000, Category.food),
        tx(d(2026, 10, 10), 5, Category.food, currency: 'USD'),
        tx(
          d(2026, 10, 10),
          9999,
          Category.salary,
          type: TransactionType.credit,
        ),
      ];
      expect(AnalyticsMath.insights(txs, rec, today, max: 1).length, 1);
      expect(AnalyticsMath.insights(const [], const [], today), isEmpty);
      expect(
        AnalyticsMath.insights(txs, const [], today)
            .any((e) => e.title == 'Biggest expense: ₹1,000'),
        isTrue,
      );
    });

    test('rupee text uses Indian grouping without paise', () {
      expect(AnalyticsMath.rupeeText(r(0)), '₹0');
      expect(AnalyticsMath.rupeeText(r(999)), '₹999');
      expect(AnalyticsMath.rupeeText(r(1000)), '₹1,000');
      expect(AnalyticsMath.rupeeText(r(123456)), '₹1,23,456');
      expect(AnalyticsMath.rupeeText(r(12345678)), '₹1,23,45,678');
      expect(AnalyticsMath.rupeeText(150), '₹1');
    });
  });
}

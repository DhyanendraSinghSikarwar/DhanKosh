import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_math.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';
import 'package:hisaab/features/forex_rates/domain/inr_minor_for.dart';
import 'package:hisaab/features/income_tracking/domain/cash_flow.dart';
import 'package:hisaab/features/income_tracking/domain/income_classifier.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_detector.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

int ist(int y, int m, int d) =>
    DateTime.utc(y, m, d, 6).millisecondsSinceEpoch - 19800000;

var _id = 0;
LedgerTx ltx({
  required int amount,
  required int ts,
  TransactionType type = TransactionType.debit,
  Category cat = Category.food,
  String? merchant = 'Netflix',
  String currency = 'INR',
  int? inr,
  bool review = false,
  int? dup,
}) =>
    LedgerTx(
      id: ++_id,
      amountMinor: amount,
      currency: currency,
      type: type,
      bankName: 'HDFC Bank',
      accountKind: AccountKind.account,
      channel: Channel.upi,
      timestamp: ts,
      hasExplicitTime: true,
      category: cat,
      transactionHash: 'h$_id',
      confidence: 1,
      needsReview: review,
      createdAt: 1,
      merchant: merchant,
      inrMinor: inr ?? (currency == 'INR' ? amount : null),
      duplicateOfId: dup,
    );

void main() {
  group('budget math (FR-10-09..15)', () {
    const food = Budget(category: Category.food, monthlyLimitMinor: 1000000);
    test('alert sample: 9,000 of 10,000 at 90 fires level 90 once', () {
      final hit = BudgetMath.pendingAlert(
        budget: food,
        usedMinor: 900000,
        alertPercent: 90,
        yearMonth: '2026-10',
        alerted: {},
      )!;
      expect(hit.level, 90);
      expect(hit.key, 'budget:FOOD:2026-10:90');
      expect(
        BudgetMath.pendingAlert(
          budget: food,
          usedMinor: 900000,
          alertPercent: 90,
          yearMonth: '2026-10',
          alerted: {hit.key},
        ),
        isNull,
      );
    });

    test('100 level wins when reached; key per level', () {
      final hit = BudgetMath.pendingAlert(
        budget: food,
        usedMinor: 1020000,
        alertPercent: 90,
        yearMonth: '2026-10',
        alerted: {'budget:FOOD:2026-10:90'},
      )!;
      expect(hit.level, 100);
      expect(
        BudgetMath.pendingAlert(
          budget: food,
          usedMinor: 899999,
          alertPercent: 90,
          yearMonth: '2026-10',
          alerted: {},
        ),
        isNull,
      );
    });

    test('levels distinct and keys for emiLoan are snake upper', () {
      expect(BudgetMath.levels(100), [100]);
      expect(BudgetMath.levels(80), [100, 80]);
      final hit = BudgetMath.pendingAlert(
        budget:
            const Budget(category: Category.emiLoan, monthlyLimitMinor: 100),
        usedMinor: 100,
        alertPercent: 95,
        yearMonth: '2026-10',
        alerted: {},
      )!;
      expect(hit.key, 'budget:EMI_LOAN:2026-10:100');
    });

    test('bands, daily left, pace, analytics limit, normalise', () {
      expect(BudgetMath.band(1001, 1000, 90), BudgetBand.red);
      expect(BudgetMath.band(900, 1000, 90), BudgetBand.amber);
      expect(BudgetMath.band(899, 1000, 90), BudgetBand.normal);
      expect(BudgetMath.ringBand(800, 1000), BudgetBand.amber);
      expect(BudgetMath.daysLeft(2026, 10, 12), 20);
      expect(BudgetMath.dailyLeft(1000000, 900000, 20), 5000);
      expect(BudgetMath.dailyLeft(1000, 1000, 5), isNull);
      expect(BudgetMath.analyticsLimit(1000, 3), 3000);
      expect(
        BudgetMath.paceTick(
          singleCurrentMonth: true,
          dayOfMonth: 15,
          lengthOfMonth: 30,
        ),
        0.5,
      );
      expect(BudgetMath.normaliseAlertPercent(0), 90);
      expect(BudgetMath.normaliseAlertPercent(150), 90);
      expect(BudgetMath.normaliseAlertPercent(80), 80);
      expect(BudgetMath.isBudgetable(Category.salary), isFalse);
      expect(BudgetMath.isBudgetable(Category.food), isTrue);
    });

    test('sortedUse orders by spent/limit descending', () {
      final u = BudgetMath.sortedUse(
        [
          const Budget(category: Category.food, monthlyLimitMinor: 1000),
          const Budget(category: Category.fuel, monthlyLimitMinor: 100),
        ],
        {Category.food: 500, Category.fuel: 90},
      );
      expect(u.first.category, Category.fuel);
    });
  });

  group('spend calculators (FR-10-01..03)', () {
    final t = ist(2026, 10, 5);
    final txs = [
      ltx(amount: 10000, ts: t),
      ltx(amount: 5000, ts: t, type: TransactionType.investment),
      ltx(amount: 7000, ts: t, cat: Category.transfer),
      ltx(amount: 9000, ts: t, review: true),
      ltx(amount: 9000, ts: t, dup: 1),
      ltx(
        amount: 3000,
        ts: t,
        type: TransactionType.credit,
        cat: Category.refund,
      ),
      ltx(amount: 100, ts: t, currency: 'USD'),
    ];
    test('ledgerSpent, netSpent, outflow, unpriced', () {
      expect(SpendCalc.ledgerSpent(txs), 10000);
      expect(SpendCalc.netSpent(txs), 7000);
      expect(SpendCalc.outflow(txs), 15000);
      expect(SpendCalc.unpricedCount(txs), 1);
      expect(SpendCalc.netSpent([txs[5]]), 0);
    });
    test('changePercent', () {
      expect(SpendCalc.changePercent(150, 100), 50);
      expect(SpendCalc.changePercent(10, 0), isNull);
    });
  });

  group('recurring detection (FR-12-01..05)', () {
    final today = DateTime.utc(2026, 10, 12);
    test('Netflix worked example', () {
      final out = RecurringDetector.detect(
        [
          ltx(amount: 64900, ts: ist(2026, 8, 5)),
          ltx(amount: 64900, ts: ist(2026, 9, 5)),
          ltx(amount: 64900, ts: ist(2026, 10, 5)),
        ],
        today,
      );
      expect(out, hasLength(1));
      final r = out.single;
      expect(r.name, 'Netflix');
      expect(r.amountMinor, 64900);
      expect(r.dayOfMonth, 5);
      expect(r.lastPaid, DateTime.utc(2026, 10, 5));
      expect(r.nextDue, DateTime.utc(2026, 11, 5));
      expect(r.occurrences, 3);
    });

    test('day spread, one month, stale, foreign and review rows fail', () {
      expect(
        RecurringDetector.detect(
          [
            ltx(amount: 100000, ts: ist(2026, 9, 30), merchant: 'Gym'),
            ltx(amount: 100000, ts: ist(2026, 10, 2), merchant: 'Gym'),
          ],
          today,
        ),
        isEmpty,
      );
      expect(
        RecurringDetector.detect(
          [
            ltx(amount: 100, ts: ist(2026, 10, 1)),
            ltx(amount: 100, ts: ist(2026, 10, 2)),
          ],
          today,
        ),
        isEmpty,
      );
      expect(
        RecurringDetector.detect(
          [
            ltx(amount: 100, ts: ist(2026, 5, 5)),
            ltx(amount: 100, ts: ist(2026, 6, 5)),
            ltx(amount: 100, ts: ist(2026, 7, 5)),
          ],
          today,
        ),
        isEmpty,
      );
      expect(
        RecurringDetector.detect(
          [
            ltx(amount: 100, ts: ist(2026, 9, 5), review: true),
            ltx(amount: 100, ts: ist(2026, 10, 5), currency: 'USD'),
          ],
          today,
        ),
        isEmpty,
      );
    });

    test('20% band drops outliers; short key ignored', () {
      final out = RecurringDetector.detect(
        [
          ltx(amount: 10000, ts: ist(2026, 8, 5)),
          ltx(amount: 10500, ts: ist(2026, 9, 5)),
          ltx(amount: 99999, ts: ist(2026, 10, 5)),
          ltx(amount: 100, ts: ist(2026, 9, 5), merchant: 'A'),
          ltx(amount: 100, ts: ist(2026, 10, 5), merchant: 'A'),
        ],
        today,
      );
      expect(out.single.occurrences, 2);
    });

    test('next due clamps and user items replace detected by name', () {
      const item = RecurringItem(
        id: 1,
        name: 'netflix',
        amountMinor: 1,
        income: false,
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 31,
        category: Category.food,
        createdAt: 1,
      );
      expect(
        RecurringDetector.nextDueOf(item, DateTime.utc(2026, 11)),
        DateTime.utc(2026, 11, 30),
      );
      const yearly = RecurringItem(
        id: 2,
        name: 'Policy',
        amountMinor: 1,
        income: false,
        frequency: RecurringFrequency.yearly,
        dayOfMonth: 5,
        month: 3,
        category: Category.insurance,
        createdAt: 1,
      );
      expect(
        RecurringDetector.nextDueOf(yearly, today),
        DateTime.utc(2027, 3, 5),
      );
      final detected = RecurringDetector.detect(
        [
          ltx(amount: 64900, ts: ist(2026, 8, 5)),
          ltx(amount: 64900, ts: ist(2026, 9, 5)),
        ],
        today,
      );
      final merged = RecurringDetector.withManual(detected, [item], today);
      expect(merged, hasLength(1));
      expect(merged.single.manualId, 1);
      expect(
        RecurringDetector.occursOn(
          merged.single,
          DateTime.utc(2026, 2, 28),
        ),
        isTrue,
      );
    });

    test('draft validation', () {
      RecurringDraft d({String n = 'x', int a = 1, int day = 5, int? m}) =>
          RecurringDraft(
            name: n,
            amountMinor: a,
            frequency: m == null
                ? RecurringFrequency.monthly
                : RecurringFrequency.yearly,
            dayOfMonth: day,
            month: m,
            category: Category.food,
          );
      expect(d().validate(), isNull);
      expect(d(n: ' ').validate(), isNotNull);
      expect(d(a: 0).validate(), isNotNull);
      expect(d(day: 32).validate(), isNotNull);
      expect(d(m: 13).validate(), isNotNull);
      expect(d(m: 12).validate(), isNull);
    });
  });

  group('income (FR-11)', () {
    test('credit category from text', () {
      expect(
        IncomeClassifier.creditCategory('credited SALARY ACME'),
        Category.salary,
      );
      expect(
        IncomeClassifier.creditCategory('Refund of Rs 499'),
        Category.refund,
      );
      expect(IncomeClassifier.creditCategory('reversal done'), Category.refund);
      expect(
        IncomeClassifier.creditCategory('credited by UPI'),
        Category.income,
      );
    });

    test('TC-11-09 buckets', () {
      IncomeBucket b(String m, [Category c = Category.income]) =>
          IncomeClassifier.bucketOf(category: c, merchant: m);
      expect(b('Interest on FD'), IncomeBucket.depositInterest);
      expect(b('Interest credited SB'), IncomeBucket.savingsInterest);
      expect(b('Dividend'), IncomeBucket.dividend);
      expect(b('Rent received'), IncomeBucket.rent);
      expect(b('Salary reimbursement', Category.salary), IncomeBucket.excluded);
      expect(b('ACME', Category.salary), IncomeBucket.salary);
      expect(b('Friend'), IncomeBucket.other);
    });

    test('cash flow and savings rate', () {
      const f = CashFlow(
        incomeMinor: 6000000,
        spentMinor: 3500000,
        investedMinor: 1000000,
      );
      expect(f.savedMinor, 1500000);
      expect(f.ratePercent, 25);
      expect(
        const CashFlow(incomeMinor: 0, spentMinor: 1, investedMinor: 0)
            .ratePercent,
        isNull,
      );
      final s = CashFlowMath.savingsRateSeries(const [
        MonthFlow(
          yearMonth: '2026-09',
          incomeMinor: 6000000,
          spentMinor: 3500000,
          investedMinor: 0,
        ),
        MonthFlow(
          yearMonth: '2026-10',
          incomeMinor: 100,
          spentMinor: 900,
          investedMinor: 0,
        ),
        MonthFlow(
          yearMonth: '2026-08',
          incomeMinor: 0,
          spentMinor: 5,
          investedMinor: 0,
        ),
      ]);
      expect(s.map((p) => p.yearMonth), ['2026-09', '2026-10']);
      expect(s.first.percent, closeTo(41.67, 0.01));
      expect(s.last.percent, -100);
      expect(CashFlowMath.savingsRateSeries(const []), isEmpty);
      expect(CashFlowMath.bestInMonths(30, [10, 20]), 3);
      expect(CashFlowMath.bestInMonths(30, [10]), isNull);
      expect(CashFlowMath.bestInMonths(20, [10, 20]), isNull);
      expect(
        CashFlowMath.estimateYearMinor(
          salarySoFar: 5 * 50,
          latestSalary: 80,
          months: 5,
        ),
        250 + 80 * 7,
      );
      expect(CashFlowMath.scaleToYear(100, 6), 200);
    });
  });

  group('inrMinorFor (FR-23-04, A-G)', () {
    final day = (ist(2026, 10, 12) + 19800000) ~/ 86400000;
    List<ForexRate> r(Map<int, double> m) => [
          for (final e in m.entries)
            ForexRate(currency: 'USD', day: e.key, inrPerUnit: e.value),
        ];
    int? f(int amt, List<ForexRate> rates, {int? markup, String cur = 'USD'}) =>
        inrMinorFor(
          amountMinor: amt,
          currency: cur,
          timestampMs: ist(2026, 10, 12),
          markupBps: markup,
          ratesForCurrency: rates,
        );
    test('A B C D E G', () {
      expect(f(20000, r({day: 83.10})), 1662000);
      expect(f(20000, r({day: 83.10}), markup: 413), 1730641);
      expect(f(1, r({day - 11: 83, day + 8: 84}), markup: 0), 84);
      expect(f(100, r({day - 5: 10, day + 5: 20})), 1000);
      expect(f(100, []), isNull);
      expect(f(45000, [], cur: 'INR'), 45000);
    });
    test('IST boundary F', () {
      // 2026-10-12 20:00 UTC is 13 Oct 01:30 IST.
      final ms = DateTime.utc(2026, 10, 12, 20).millisecondsSinceEpoch;
      final d13 = (ms + 19800000) ~/ 86400000;
      expect(
        DateTime.fromMillisecondsSinceEpoch(d13 * 86400000, isUtc: true).day,
        13,
      );
      const rd = RateDraft;
      expect(rd, isNotNull);
      expect(
        RateDraft(currency: 'USD', day: DateTime.utc(2026), rateText: '0')
            .canSave,
        isFalse,
      );
      expect(
        RateDraft(currency: 'USD', day: DateTime.utc(2026), rateText: '83.1')
            .canSave,
        isTrue,
      );
    });
  });
}

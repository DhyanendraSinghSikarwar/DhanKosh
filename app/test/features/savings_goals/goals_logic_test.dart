// Goal progress, round-ups and salary plan maths (FR-36-03, 05, 07, 08).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/savings_goals/domain/goal.dart';
import 'package:hisaab/features/savings_goals/domain/goal_math.dart';
import 'package:hisaab/features/savings_goals/domain/round_up.dart';
import 'package:hisaab/features/savings_goals/domain/salary_plan.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

void main() {
  const goal = Goal(
    id: 1,
    name: 'Trip',
    targetMinor: 10000000,
    createdAt: 0,
  );
  GoalContribution c(int day, int rupees, {int goalId = 1}) => GoalContribution(
        id: day,
        goalId: goalId,
        amountMinor: rupees * 100,
        day: day,
      );

  group('goal progress (FR-36-03)', () {
    test('sums only its own contributions', () {
      final p = GoalMath.progress(
        goal,
        [c(100, 20000), c(110, 5000), c(111, 9999, goalId: 2)],
        120,
      );
      expect(p.savedMinor, 2500000);
      expect(p.remainingMinor, 7500000);
      expect(p.fraction, 0.25);
      expect(p.done, isFalse);
    });

    test('no contributions: no projection', () {
      final p = GoalMath.progress(goal, const [], 120);
      expect(p.projectedDay, isNull);
      expect(p.onTrack, isNull);
      expect(p.fraction, 0);
    });

    test('projection uses at least a 30 day pace', () {
      // Saved 25,000 on day 100; today 101 -> span 30 days.
      final p = GoalMath.progress(goal, [c(100, 25000)], 101);
      // remaining 75,000 at 25,000 per 30 days = 90 days.
      expect(p.projectedDay, 101 + 90);
    });

    test('projection over a longer history', () {
      // 40,000 saved since day 0, today 99 -> 100 days, rate 400/day.
      final p = GoalMath.progress(goal, [c(0, 40000)], 99);
      // remaining 60,000 -> 150 days.
      expect(p.projectedDay, 99 + 150);
    });

    test('target day: on track, behind and monthly need', () {
      const tight = Goal(
        id: 1,
        name: 'Trip',
        targetMinor: 10000000,
        targetDay: 99 + 120,
        createdAt: 0,
      );
      final behind = GoalMath.progress(tight, [c(0, 40000)], 99);
      expect(behind.onTrack, isFalse);
      // remaining 60,000 over 120 days = 4 months -> 15,000 a month.
      expect(behind.requiredPerMonthMinor, 1500000);
      final ok = GoalMath.progress(
        const Goal(
          id: 1,
          name: 'Trip',
          targetMinor: 10000000,
          targetDay: 99 + 200,
          createdAt: 0,
        ),
        [c(0, 40000)],
        99,
      );
      expect(ok.onTrack, isTrue);
    });

    test('reached goal', () {
      final p = GoalMath.progress(goal, [c(1, 100000), c(2, 5)], 50);
      expect(p.done, isTrue);
      expect(p.fraction, 1);
      expect(p.remainingMinor, 0);
      expect(p.projectedDay, 50);
      expect(p.requiredPerMonthMinor, isNull);
    });

    test('validation', () {
      expect(const GoalDraft(name: ' ', targetMinor: 5).validate(), isNotNull);
      expect(const GoalDraft(name: 'A', targetMinor: 0).validate(), isNotNull);
      expect(const GoalDraft(name: 'A', targetMinor: 1).validate(), isNull);
    });
  });

  group('round-ups (FR-36-05)', () {
    test('gap to the next multiple of the step', () {
      expect(RoundUp.amountFor(12350, 10), 650); // 123.50 -> 130
      expect(RoundUp.amountFor(12000, 10), 0); // exact multiple
      expect(RoundUp.amountFor(12350, 50), 2650); // -> 150
      expect(RoundUp.amountFor(12350, 100), 7650); // -> 200
      expect(RoundUp.amountFor(1, 10), 999);
      expect(RoundUp.amountFor(0, 10), 0);
    });

    test('totals expenses in the month only', () {
      final from = DateTime.utc(2026, 10).millisecondsSinceEpoch;
      final to = DateTime.utc(2026, 11).millisecondsSinceEpoch;
      final txs = [
        fakeTx(1, 12350, DateTime.utc(2026, 10, 3, 6)), // 650
        fakeTx(2, 4900, DateTime.utc(2026, 10, 9, 6)), // 100
        fakeTx(3, 5000, DateTime.utc(2026, 10, 9, 6)), // exact: 0
        fakeTx(
          4,
          9999,
          DateTime.utc(2026, 10, 9, 6),
          type: TransactionType.credit,
        ), // income ignored
        fakeTx(
          5,
          9999,
          DateTime.utc(2026, 10, 9, 6),
          type: TransactionType.investment,
        ), // investment ignored
        fakeTx(6, 12350, DateTime.utc(2026, 9, 30, 6)), // other month
        fakeTx(7, 12350, DateTime.utc(2026, 10, 9, 6), needsReview: true),
        fakeTx(
          8,
          12350,
          DateTime.utc(2026, 10, 9, 6),
          category: Category.transfer,
        ),
      ];
      final r = RoundUp.total(txs, 10, from, to);
      expect(r.totalMinor, 750);
      expect(r.count, 2);
      // Step 100: 123.50 -> 76.50, 49 -> 51, 50 -> 50.
      expect(RoundUp.total(txs, 100, from, to).totalMinor, 17750);
    });
  });

  group('salary plan (FR-36-07, FR-36-08)', () {
    test('encode, decode and validity', () {
      expect(SalaryPlan.standard.valid, isTrue);
      expect(SalaryPlan.decode('30:20:50').encode(), '30:20:50');
      expect(SalaryPlan.decode('30:20:60').encode(), '20:20:60');
      expect(SalaryPlan.decode('x').encode(), '20:20:60');
      expect(SalaryPlan.decode(null).encode(), '20:20:60');
      expect(
        const SalaryPlan(savingsPct: -10, investPct: 60, spendPct: 50).valid,
        isFalse,
      );
    });

    test('plan versus actual lines', () {
      const m = MonthActual(
        monthStartMs: 0,
        incomeMinor: 10000000,
        investedMinor: 1500000,
        spentMinor: 6000000,
      );
      expect(m.savedMinor, 2500000);
      final l = SalaryPlanMath.lines(SalaryPlan.standard, m);
      expect(l.map((e) => e.label), ['Savings', 'Investments', 'Spending']);
      expect(l[0].plannedMinor, 2000000);
      expect(l[0].deltaMinor, 500000);
      expect(l[1].plannedMinor, 2000000);
      expect(l[1].deltaMinor, -500000);
      expect(l[2].plannedMinor, 6000000);
      expect(l[2].deltaMinor, 0);
    });

    test('saved never goes below zero; no income plans nothing', () {
      const over = MonthActual(
        monthStartMs: 0,
        incomeMinor: 100,
        investedMinor: 500,
        spentMinor: 900,
      );
      expect(over.savedMinor, 0);
      const none = MonthActual(
        monthStartMs: 0,
        incomeMinor: 0,
        investedMinor: 0,
        spentMinor: 0,
      );
      expect(
        SalaryPlanMath.lines(SalaryPlan.standard, none)
            .every((e) => e.plannedMinor == 0),
        isTrue,
      );
    });
  });
}

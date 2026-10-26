import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/utils/combine_latest.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/savings_goals/data/goal_repository_impl.dart';
import 'package:hisaab/features/savings_goals/domain/goal.dart';
import 'package:hisaab/features/savings_goals/domain/goal_math.dart';
import 'package:hisaab/features/savings_goals/domain/goal_settings.dart';
import 'package:hisaab/features/savings_goals/domain/round_up.dart';
import 'package:hisaab/features/savings_goals/domain/salary_plan.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'goals_providers.g.dart';

// Savings Goals, Round-ups and Salary Plan (F-36). Tracking only.

/// Goals and contributions (F-36).
@Riverpod(keepAlive: true)
GoalRepository goalRepository(Ref ref) =>
    GoalRepositoryImpl(ref.watch(appDatabaseProvider));

/// Progress of every goal, live (FR-36-03). Embeddable on Home.
@riverpod
Stream<List<GoalProgress>> goalProgressList(Ref ref) {
  final repo = ref.watch(goalRepositoryProvider);
  return combineLatest<List<GoalProgress>>(
    [repo.watchGoals(), repo.watchContributions()],
    (v) {
      final today = Ist.dayOf(DateTime.now().millisecondsSinceEpoch);
      final cs = v[1]! as List<GoalContribution>;
      return [
        for (final g in v[0]! as List<Goal>) GoalMath.progress(g, cs, today),
      ];
    },
  );
}

/// Round-up step in rupees (FR-36-05).
@riverpod
Stream<int> roundUpStep(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(GoalSettings.roundUpStep);

/// Goal the round-ups are shown against; 0 for none (FR-36-05).
@riverpod
Stream<int> roundUpGoal(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(GoalSettings.roundUpGoal);

/// This month's virtual round-ups (FR-36-05): "You could have saved".
/// Embeddable on Home.
@riverpod
Stream<RoundUpSummary> roundUpThisMonth(Ref ref) async* {
  final step = await ref.watch(roundUpStepProvider.future);
  final now = Ist.dateOf(DateTime.now().millisecondsSinceEpoch);
  final from = Ist.startMs(now.year, now.month, 1);
  final to = Ist.startMs(now.year, now.month + 1, 1);
  await for (final txs in ref
      .watch(transactionRepositoryProvider)
      .watch(LedgerFilter(kind: TxKind.spends, fromMs: from, toMs: to))) {
    yield RoundUp.total(txs, step, from, to);
  }
}

/// The salary split target (FR-36-07).
@riverpod
Stream<SalaryPlan> salaryPlan(Ref ref) => ref
    .watch(settingsRepositoryProvider)
    .watch(GoalSettings.salaryPlan)
    .map(SalaryPlan.decode);

/// The last six months, newest first (FR-36-08).
@riverpod
Stream<List<MonthActual>> salaryMonths(Ref ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final now = Ist.dateOf(DateTime.now().millisecondsSinceEpoch);
  final starts = <int>[];
  for (var i = 0; i < 6; i++) {
    final d = DateTime.utc(now.year, now.month - i);
    starts.add(Ist.startMs(d.year, d.month, 1));
  }
  return combineLatest<List<MonthActual>>(
    [
      for (var i = 0; i < starts.length; i++)
        repo.watchTotals(
          fromMs: starts[i],
          toMs:
              i == 0 ? Ist.startMs(now.year, now.month + 1, 1) : starts[i - 1],
        ),
    ],
    (v) => [
      for (var i = 0; i < v.length; i++)
        MonthActual(
          monthStartMs: starts[i],
          incomeMinor: (v[i]! as PeriodTotals).incomeMinor,
          investedMinor: (v[i]! as PeriodTotals).investedMinor,
          spentMinor: (v[i]! as PeriodTotals).netSpentMinor,
        ),
    ],
  );
}

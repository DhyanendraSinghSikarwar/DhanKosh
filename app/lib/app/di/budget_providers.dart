import 'dart:async';

import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_math.dart';
import 'package:hisaab/features/income_tracking/domain/cash_flow.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:parser_core/parser_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'budget_providers.g.dart';

// Budget, spend and cash-flow view state (F-10, F-11). Presentation reads
// these; repositories come from phase4_providers.dart.

/// Month shown on the Budgets screen (FR-10-10); never after this month.
@riverpod
class BudgetMonth extends _$BudgetMonth {
  @override
  MonthRange build() => MonthRange.of(DateTime.now());

  /// Previous month.
  void previous() => state = state.previous;

  /// Next month, capped at the current one.
  void next() {
    if (!state.isCurrent(DateTime.now())) state = state.next;
  }
}

/// Alert percent from settings, normalised (FR-10-12).
@riverpod
Stream<int> budgetAlertPercent(Ref ref) => ref
    .watch(settingsRepositoryProvider)
    .watch(SettingKeys.budgetAlertPercent)
    .map(BudgetMath.normaliseAlertPercent);

/// Budget lines with spend for [month], most used first (FR-10-10).
@riverpod
Stream<List<BudgetUse>> budgetUses(Ref ref, MonthRange month) {
  final repo = ref.watch(budgetRepositoryProvider);
  return _combine(
    repo.watchAll(),
    repo.watchCategoryTotals(month.startMs, month.endMs - 1),
    BudgetMath.sortedUse,
  );
}

/// Month shown on the Income screen.
@riverpod
class IncomeMonth extends _$IncomeMonth {
  @override
  MonthRange build() => MonthRange.of(DateTime.now());

  /// Previous month.
  void previous() => state = state.previous;

  /// Next month, capped at the current one.
  void next() {
    if (!state.isCurrent(DateTime.now())) state = state.next;
  }
}

/// Twelve months of income/spend ending with [month], oldest first.
@riverpod
Stream<List<MonthFlow>> monthlyFlows(Ref ref, MonthRange month) {
  var from = month;
  for (var i = 0; i < 11; i++) {
    from = from.previous;
  }
  return ref
      .watch(incomeRepositoryProvider)
      .watchMonthlyFlows(from.startMs, month.endMs - 1);
}

/// Spend per category for [month] (DEBIT + INVESTMENT).
@riverpod
Stream<Map<Category, int>> monthCategorySpend(Ref ref, MonthRange month) => ref
    .watch(budgetRepositoryProvider)
    .watchCategoryTotals(month.startMs, month.endMs - 1);

Stream<List<BudgetUse>> _combine(
  Stream<List<Budget>> budgets,
  Stream<Map<Category, int>> spent,
  List<BudgetUse> Function(List<Budget>, Map<Category, int>) f,
) async* {
  List<Budget>? b;
  Map<Category, int>? s;
  final ctl = StreamController<void>();
  final subs = [
    budgets.listen((v) {
      b = v;
      ctl.add(null);
    }),
    spent.listen((v) {
      s = v;
      ctl.add(null);
    }),
  ];
  try {
    await for (final _ in ctl.stream) {
      if (b != null && s != null) yield f(b!, s!);
    }
  } finally {
    for (final x in subs) {
      await x.cancel();
    }
    await ctl.close();
  }
}

// Goals screen: goals, round-ups and the salary plan (FR-36-01..09).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/goals_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/savings_goals/data/goal_repository_impl.dart';
import 'package:hisaab/features/savings_goals/domain/goal.dart';
import 'package:hisaab/features/savings_goals/domain/goal_settings.dart';
import 'package:hisaab/features/savings_goals/presentation/goals_screen.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

void main() {
  late TestEnv env;
  late GoalRepositoryImpl repo;
  setUp(() {
    env = TestEnv();
    repo = GoalRepositoryImpl(env.db);
  });
  tearDown(() => env.close());

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(env.txs),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          goalRepositoryProvider.overrideWithValue(repo),
          hideAmountsProvider.overrideWith((_) => Stream.value(false)),
        ],
        child: const MaterialApp(home: GoalsScreen()),
      ),
    );
    await settle(t);
  }

  testWidgets('add a goal, add money, see progress and projection', (t) async {
    await pump(t);
    expect(find.byKey(const Key('goals-empty')), findsOneWidget);
    await t.tap(find.byKey(const Key('goal-add')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const Key('goal-save')));
    await t.pump();
    expect(find.byKey(const Key('goal-error')), findsOneWidget);
    await t.enterText(find.byKey(const Key('goal-name')), 'Demo Trip');
    await t.enterText(find.byKey(const Key('goal-target')), '50000');
    await t.tap(find.byKey(const Key('goal-save')));
    await settle(t);
    await t.pump(const Duration(seconds: 1));
    final goals = await t.runAsync(() => repo.watchGoals().first);
    expect(goals!.single.targetMinor, 5000000);
    final id = goals.single.id;
    expect(
      find.text('₹0.00 of ₹50,000.00'.replaceAll('.00', '')),
      findsOneWidget,
    );

    await t.tap(find.byKey(Key('goal-contribute-$id')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.enterText(find.byKey(const Key('contrib-amount')), '10000');
    await t.tap(find.byKey(const Key('contrib-save')));
    await settle(t);
    await t.pump(const Duration(seconds: 1));
    expect(find.byKey(Key('goal-saved-$id')), findsOneWidget);
    expect(find.textContaining('₹10,000 of ₹50,000'), findsOneWidget);
    expect(find.byKey(Key('goal-projection-$id')), findsOneWidget);
    expect(await t.runAsync(() => env.count('transactions')), 0);
    await teardownApp(t);
  });

  testWidgets('round-up card: you could have saved, step setting (FR-36-05)',
      (t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await t.runAsync(() async {
      env.clock = now;
      await env.ingest(
        parsed(amountMinor: 12350, time: now - 3600000, ref: 'r1'),
      );
      await env.ingest(
        parsed(
          amountMinor: 4900,
          time: now - 7200000,
          ref: 'r2',
          merchant: 'Cafe',
        ),
      );
      await repo.addGoal(
        const GoalDraft(name: 'Demo Trip', targetMinor: 5000000),
      );
    });
    // Only meaningful when both rows fall in the current IST month.
    final d = Ist.dateOf(now);
    final startOfMonth = Ist.startMs(d.year, d.month, 1);
    final inMonth = now - 7200000 >= startOfMonth;
    await pump(t);
    if (inMonth) {
      expect(
        find.text('You could have saved ₹7.50 this month'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('roundup-step-100')));
      await settle(t);
      expect(
        await t.runAsync(() => env.settings.read(GoalSettings.roundUpStep)),
        100,
      );
      expect(
        find.text('You could have saved ₹127.50 this month'),
        findsOneWidget,
      );
    }
    expect(find.byKey(const Key('roundup-goal')), findsOneWidget);
    await t.runAsync(() => env.settings.write(GoalSettings.roundUpGoal, 1));
    await settle(t);
    expect(find.textContaining('Nothing is moved'), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('salary plan must add up to 100 and is saved (FR-36-07)',
      (t) async {
    await pump(t);
    await t.enterText(find.byKey(const Key('plan-savings')), '30');
    await t.tap(find.byKey(const Key('plan-save')));
    await t.pump();
    expect(find.byKey(const Key('plan-error')), findsOneWidget);
    await t.enterText(find.byKey(const Key('plan-spend')), '50');
    await t.tap(find.byKey(const Key('plan-save')));
    await settle(t);
    expect(find.byKey(const Key('plan-error')), findsNothing);
    expect(
      await t.runAsync(() => env.settings.read(GoalSettings.salaryPlan)),
      '30:20:50',
    );
    expect(find.byKey(const Key('plan-month-0')), findsOneWidget);
    await teardownApp(t);
  });
}

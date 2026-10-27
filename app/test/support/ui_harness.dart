import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/expense_tracking/data/budget_repository_impl.dart';
import 'package:hisaab/features/income_tracking/data/income_repository_impl.dart';

import 'test_env.dart';

/// Pumps [routes] over a [TestEnv] database with the real repositories.
Future<void> pumpApp(
  WidgetTester t,
  TestEnv env,
  List<RouteBase> routes, {
  String initial = '/',
  bool dark = false,
}) async {
  final router = GoRouter(initialLocation: initial, routes: routes);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        accountRepositoryProvider.overrideWithValue(env.accounts),
        transactionRepositoryProvider.overrideWithValue(env.txs),
        settingsRepositoryProvider.overrideWithValue(env.settings),
        budgetRepositoryProvider
            .overrideWithValue(BudgetRepositoryImpl(env.db)),
        incomeRepositoryProvider
            .overrideWithValue(IncomeRepositoryImpl(env.txs)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: dark ? AppTheme.dark() : AppTheme.light(),
      ),
    ),
  );
  await settle(t);
}

/// Lets drift streams emit (real async), then rebuilds.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump();
  }
}

/// Unmounts so drift stream timers finish before the test ends.
Future<void> teardownApp(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await t.pump(const Duration(milliseconds: 10));
}

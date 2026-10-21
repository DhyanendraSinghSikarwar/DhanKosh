import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/dashboard_home/presentation/dashboard_home_screen.dart';
import 'package:hisaab/features/income_tracking/presentation/income_tracking_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

List<RouteBase> _routes() => [
      GoRoute(path: '/', builder: (_, __) => const IncomeTrackingScreen()),
      GoRoute(path: '/home', builder: (_, __) => const DashboardHomeScreen()),
      for (final p in ['/budgets', '/income', '/accounts', '/more', '/review'])
        GoRoute(path: p, builder: (_, __) => Scaffold(body: Text('page $p'))),
    ];

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  int now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> seed(WidgetTester t, {bool hide = false}) =>
      t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, hide);
        await env.ingest(
          parsed(
            amountMinor: 5000000,
            type: TransactionType.credit,
            merchant: 'Salary',
            category: Category.salary,
            time: now() - 2000,
            ref: 'I1',
          ),
        );
        await env.ingest(
          parsed(amountMinor: 1000000, time: now() - 1000, ref: 'E1'),
        );
      });

  // FR-11-05, FR-11-06
  testWidgets('income screen shows cash flow', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes());
    expect(find.text('₹50,000'), findsOneWidget);
    expect(find.text('₹40,000'), findsOneWidget); // saved
    expect(find.text('Savings rate 80%'), findsOneWidget);
    expect(find.byKey(const Key('income_chart_card')), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('income screen masked', (t) async {
    await seed(t, hide: true);
    await pumpApp(t, env, _routes());
    expect(find.textContaining('50,000'), findsNothing);
    expect(find.textContaining('••••'), findsWidgets);
    await teardownApp(t);
  });

  testWidgets('income screen empty', (t) async {
    await pumpApp(t, env, _routes());
    expect(find.text('No income yet'), findsOneWidget);
    await teardownApp(t);
  });

  // FR-11-06 Home cash flow
  testWidgets('home cash flow card', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes(), initial: '/home');
    expect(find.byKey(const Key('home_cashflow')), findsOneWidget);
    expect(find.textContaining('Saved ₹40,000 · 80%'), findsOneWidget);
    await teardownApp(t);
  });
}

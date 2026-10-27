import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/dashboard_home/presentation/dashboard_home_screen.dart';
import 'package:hisaab/features/expense_tracking/data/budget_repository_impl.dart';
import 'package:hisaab/features/expense_tracking/presentation/budget_widgets.dart';
import 'package:hisaab/features/expense_tracking/presentation/expense_tracking_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

List<RouteBase> _routes() => [
      GoRoute(path: '/', builder: (_, __) => const ExpenseTrackingScreen()),
      GoRoute(path: '/home', builder: (_, __) => const DashboardHomeScreen()),
      for (final p in ['/budgets', '/income', '/accounts', '/more', '/review'])
        GoRoute(path: p, builder: (_, __) => Scaffold(body: Text('page $p'))),
    ];

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  int now() => DateTime.now().millisecondsSinceEpoch;

  test('parseRupeesToMinor', () {
    expect(parseRupeesToMinor('12,500.5'), 1250050);
    expect(parseRupeesToMinor('0'), 0);
    expect(parseRupeesToMinor('abc'), isNull);
  });

  Future<void> seed(WidgetTester t, {bool hide = false}) =>
      t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, hide);
        final r = BudgetRepositoryImpl(env.db);
        await r.save(Category.food, 100000); // 1,000: spent 1,500 -> over
        await r.save(Category.shopping, 1000000); // 10,000: spent 2,000
        await env.ingest(
          parsed(amountMinor: 150000, time: now() - 1000, ref: 'F1'),
        );
        await env.ingest(
          parsed(
            amountMinor: 200000,
            time: now() - 2000,
            ref: 'S1',
            merchant: 'Shop',
            category: Category.shopping,
          ),
        );
      });

  // FR-10-10
  testWidgets('bands: over limit red text, sorted by use', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes());
    expect(find.byKey(const Key('budget_card_food')), findsOneWidget);
    expect(find.text('Over by ₹500.00'), findsOneWidget);
    expect(find.byKey(const Key('budget_pct_food')), findsOneWidget);
    final food = t.getTopLeft(find.byKey(const Key('budget_card_food')));
    final shop = t.getTopLeft(find.byKey(const Key('budget_card_shopping')));
    expect(food.dy, lessThan(shop.dy));
    expect(find.byKey(const Key('budget_pace')), findsWidgets);
    await teardownApp(t);
  });

  // FR-10-10, FR-10-12 masking
  testWidgets('amounts masked', (t) async {
    await seed(t, hide: true);
    await pumpApp(t, env, _routes());
    expect(find.textContaining('1,500'), findsNothing);
    expect(find.textContaining('••••'), findsWidgets);
    await teardownApp(t);
  });

  // FR-10-10 empty
  testWidgets('empty state', (t) async {
    await pumpApp(t, env, _routes());
    expect(find.text('No budgets yet'), findsOneWidget);
    await teardownApp(t);
  });

  // FR-10-09 add, edit, delete
  testWidgets('add then delete a budget', (t) async {
    await pumpApp(t, env, _routes());
    await t.tap(find.byKey(const Key('budget_add')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('budget_category')));
    await t.pumpAndSettle();
    expect(find.text('Salary'), findsNothing);
    await t.tap(find.text('Groceries').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('budget_amount')), '5000');
    await t.pump();
    await t.tap(find.byKey(const Key('budget_save')));
    await t.pumpAndSettle();
    await settle(t);
    final r = BudgetRepositoryImpl(env.db);
    final all = await t.runAsync(r.all);
    expect(all!.single.monthlyLimitMinor, 500000);
    expect(find.byKey(const Key('budget_card_groceries')), findsOneWidget);

    await t.tap(find.byKey(const Key('budget_card_groceries')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('budget_delete')));
    await t.pumpAndSettle();
    await settle(t);
    expect(await t.runAsync(r.all), isEmpty);
    await teardownApp(t);
  });

  // FR-10-14 Home rings
  testWidgets('home rings and masked', (t) async {
    t.view.physicalSize = const Size(800, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(
      () => env.settings.write(
        SectionLayout.key(ScreenIds.home),
        SectionLayout.encode(
          SectionLayout.setVisible(
            SectionLayout.defaults(ScreenIds.home),
            'budgets',
            visible: true,
          ),
        ),
      ),
    );
    await seed(t);
    await pumpApp(t, env, _routes(), initial: '/home');
    expect(find.byKey(const Key('home_budgets')), findsOneWidget);
    expect(find.byKey(const Key('home_ring_food')), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('home rings empty prompts Set budgets', (t) async {
    t.view.physicalSize = const Size(800, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(
      () => env.settings.write(
        SectionLayout.key(ScreenIds.home),
        SectionLayout.encode(
          SectionLayout.setVisible(
            SectionLayout.defaults(ScreenIds.home),
            'budgets',
            visible: true,
          ),
        ),
      ),
    );
    await t.runAsync(() => env.ingest(parsed(time: now() - 1000, ref: 'X')));
    await pumpApp(t, env, _routes(), initial: '/home');
    expect(find.text('Set budgets'), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('home rings masked', (t) async {
    await seed(t, hide: true);
    t.view.physicalSize = const Size(800, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(
      () => env.settings.write(
        SectionLayout.key(ScreenIds.home),
        SectionLayout.encode(
          SectionLayout.setVisible(
            SectionLayout.defaults(ScreenIds.home),
            'budgets',
            visible: true,
          ),
        ),
      ),
    );
    await pumpApp(t, env, _routes(), initial: '/home');
    expect(find.byKey(const Key('home_ring_spent_food')), findsOneWidget);
    expect(
      (t.widget(find.byKey(const Key('home_ring_spent_food'))) as Text).data,
      contains('••••'),
    );
    await teardownApp(t);
  });
}

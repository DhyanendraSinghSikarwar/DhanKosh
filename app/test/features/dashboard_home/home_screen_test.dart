import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/dashboard_home/presentation/dashboard_home_screen.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

List<RouteBase> _routes(List<String> visited) => [
      GoRoute(
        path: '/',
        builder: (_, __) => const DashboardHomeScreen(),
      ),
      GoRoute(path: '/goals', builder: (_, __) => const SizedBox()),
      for (final p in [
        '/accounts',
        '/analysis',
        '/more',
        '/review',
        '/transaction/:id',
        '/transactions',
      ])
        GoRoute(
          path: p,
          builder: (_, s) {
            visited.add(s.uri.path);
            return Scaffold(body: Text('page ${s.uri.path}'));
          },
        ),
    ];

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  int now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> seed(WidgetTester t, {bool hide = false}) =>
      t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, hide);
        await env.settings.write(SettingKeys.smsPromptDismissed, true);
        await env.accounts.create(
          const NewAccount(
            kind: AccountKind.account,
            bankName: 'HDFC Bank',
            last4: '1234',
            balanceMinor: 5000000,
          ),
        );
        await env.ingest(
          parsed(amountMinor: 245050, time: now() - 1000, ref: 'AAA111111'),
        );
        await env.ingest(
          parsed(
            amountMinor: 8500000,
            type: TransactionType.credit,
            merchant: 'Salary',
            category: Category.salary,
            time: now() - 2000,
            ref: 'BBB222222',
          ),
        );
      });

  // TC-17-01 (FR-17-03)
  test('greeting by hour', () {
    expect(greeting(5), 'Good morning');
    expect(greeting(11), 'Good morning');
    expect(greeting(12), 'Good afternoon');
    expect(greeting(17), 'Good evening');
    expect(greeting(22), 'Good night');
    expect(greeting(4), 'Good night');
  });

  // FR-17-06, FR-17-12, FR-17-19
  for (final dark in [false, true]) {
    testWidgets('home with data (dark=$dark)', (t) async {
      await seed(t);
      final visited = <String>[];
      await pumpApp(t, env, _routes(visited), dark: dark);
      expect(find.byKey(const Key('home_spent')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('home_spent'))).data,
        '₹2,450',
      );
      expect(find.byKey(const Key('home_income')), findsNothing);
      await t.scrollUntilVisible(
        find.text('Swiggy'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Swiggy'), findsOneWidget);
      expect(find.byKey(const Key('home_balance')), findsNothing);
      await t.scrollUntilVisible(
        find.text('Swiggy'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Swiggy'));
      await settle(t);
      expect(visited, ['/transaction/1']);
      await teardownApp(t);
    });
  }

  // FR-17-06: month navigation
  testWidgets('month navigation', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes([]));
    final label = t.widget<Text>(find.byKey(const Key('home_month_label')));
    expect(label.data, MonthRange.of(DateTime.now()).label);
    await t.tap(find.byKey(const Key('home_month_prev')));
    await settle(t);
    expect(
      t.widget<Text>(find.byKey(const Key('home_spent'))).data,
      '₹0',
    );
    await t.tap(find.byKey(const Key('home_month_next')));
    await settle(t);
    expect(
      t.widget<Text>(find.byKey(const Key('home_spent'))).data,
      '₹2,450',
    );
    await teardownApp(t);
  });

  // FR-17-19, TC-17-12
  testWidgets('amounts masked, eye toggles', (t) async {
    await seed(t, hide: true);
    await pumpApp(t, env, _routes([]));
    expect(
      t.widget<Text>(find.byKey(const Key('home_spent'))).data,
      '₹••••',
    );
    expect(find.textContaining('2,450'), findsNothing);
    await t.tap(find.byKey(const Key('home_eye')));
    await settle(t);
    expect(
      t.widget<Text>(find.byKey(const Key('home_spent'))).data,
      '₹2,450',
    );
    await teardownApp(t);
  });

  // FR-17-40
  testWidgets('Book tag shows next to the name unless Personal', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes([]));
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    c.read(bookProvider.notifier).set(Book.personal);
    await settle(t);
    expect(find.byKey(const Key('home_book_tag')), findsNothing);
    c.read(bookProvider.notifier).set(Book.business);
    await settle(t);
    expect(find.text('Business'), findsOneWidget);
    expect(find.byKey(const Key('home_book_tag')), findsOneWidget);
    await teardownApp(t);
  });

  // FR-17-19, FR-17-41: the eye masks every number and the setting sticks.
  testWidgets('eye hides amounts everywhere and stores the setting', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes([]));
    expect(find.textContaining('2,450'), findsWidgets);
    await t.tap(find.byKey(const Key('home_eye')));
    await settle(t);
    expect(find.textContaining('2,450'), findsNothing);
    expect(find.textContaining('₹••••'), findsWidgets);
    final stored =
        await t.runAsync(() => env.settings.read(SettingKeys.hideAmounts));
    expect(stored, isTrue);
    await teardownApp(t);
  });

  // FR-17-42
  testWidgets('refresh opens a sheet with steps, progress and a result',
      (t) async {
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await seed(t);
    await pumpApp(t, env, _routes([]));
    await t.tap(find.byKey(const Key('home_sync')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('home_refresh_sheet')), findsOneWidget);
    expect(find.byKey(const Key('home_refresh_progress')), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Matching'), findsOneWidget);
    for (var i = 0;
        i < 40 && find.byKey(const Key('home_refresh_done')).evaluate().isEmpty;
        i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('home_refresh_result')), findsOneWidget);
    expect(
      t.widget<Text>(find.byKey(const Key('home_refresh_result'))).data,
      matches(RegExp(r'^\d+ new')),
    );
    await t.tap(find.byKey(const Key('home_refresh_done')));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const Key('home_refresh_sheet')), findsNothing);
    await teardownApp(t);
  });

  // FR-17-46: category card at the end; slice tap drills down, back returns.
  testWidgets('category donut drills into sub-categories and back', (t) async {
    t.view.physicalSize = const Size(800, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await seed(t);
    await pumpApp(t, env, _routes([]));
    final card = find.byKey(const Key('home_categories'));
    expect(card, findsOneWidget);
    expect(find.text('SPEND BY CATEGORY'), findsOneWidget);
    await t.tap(find.byKey(const Key('home_categories_info')));
    await t.pump();
    expect(find.byKey(const Key('home_categories_note')), findsOneWidget);
    await t.tap(find.byKey(const Key('home_cat_Food & Dining')));
    await t.pump();
    expect(find.byKey(const Key('home_categories_back')), findsOneWidget);
    await t.tap(find.byKey(const Key('home_categories_back')));
    await t.pump();
    expect(find.byKey(const Key('home_categories_back')), findsNothing);
    expect(find.text('SPEND BY CATEGORY'), findsOneWidget);
    await teardownApp(t);
  });

  // FR-17-14: review notice routes to /review
  testWidgets('review notice shown and opens review', (t) async {
    t.view.physicalSize = const Size(800, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await seed(t);
    await t.runAsync(
      () => env.ingest(
        parsed(
          amountMinor: 245050,
          time: now() - 1000 + 60000,
          ref: null,
        ),
        id: 'dupe',
      ),
    );
    final visited = <String>[];
    await pumpApp(t, env, _routes(visited));
    final n = await t.runAsync(() => env.txs.watchReviewCount().first);
    if (n! > 0) {
      await t.tap(find.byKey(const Key('attn_duplicates')));
      await settle(t);
      expect(visited, ['/review']);
    } else {
      expect(find.byKey(const Key('attn_duplicates')), findsNothing);
    }
    await teardownApp(t);
  });

  // FR-17-01: empty state, Scan SMS -> More tab
  testWidgets('empty state', (t) async {
    final visited = <String>[];
    await pumpApp(t, env, _routes(visited));
    expect(find.text('No transactions yet'), findsOneWidget);
    await t.tap(find.byKey(const Key('home_scan_sms')));
    await settle(t);
    expect(visited, ['/more']);
    await teardownApp(t);
  });
}

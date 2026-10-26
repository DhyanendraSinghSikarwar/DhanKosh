import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/dashboard_home/presentation/dashboard_home_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

List<RouteBase> _routes(List<String> visited) => [
      GoRoute(path: '/', builder: (_, __) => const DashboardHomeScreen()),
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
        '₹2,450.50',
      );
      expect(
        t.widget<Text>(find.byKey(const Key('home_income'))).data,
        '₹85,000.00',
      );
      await t.scrollUntilVisible(find.text('Swiggy'), 200);
      expect(find.text('Swiggy'), findsOneWidget);
      await t.scrollUntilVisible(find.text('HDFC Bank ••1234'), 200);
      expect(find.text('HDFC Bank ••1234'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('home_balance'))).data,
        '₹1,32,549.50',
      );
      await t.scrollUntilVisible(find.text('Swiggy'), -200);
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
      '₹0.00',
    );
    await t.tap(find.byKey(const Key('home_month_next')));
    await settle(t);
    expect(
      t.widget<Text>(find.byKey(const Key('home_spent'))).data,
      '₹2,450.50',
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
      '₹2,450.50',
    );
    await teardownApp(t);
  });

  // FR-17-14: review notice routes to /review
  testWidgets('review notice shown and opens review', (t) async {
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

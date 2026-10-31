import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/presentation/account_detail_screen.dart';
import 'package:hisaab/features/accounts_management/presentation/accounts_management_screen.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

final _routes = <RouteBase>[
  GoRoute(
    path: '/',
    builder: (_, __) => const AccountsManagementScreen(),
    routes: [
      GoRoute(
        path: 'accounts/:id',
        builder: (_, s) =>
            AccountDetailScreen(accountId: int.parse(s.pathParameters['id']!)),
      ),
    ],
  ),
  GoRoute(
    path: '/accounts/:id',
    builder: (_, s) =>
        AccountDetailScreen(accountId: int.parse(s.pathParameters['id']!)),
  ),
];

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<void> seed(WidgetTester t) => t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, false);
        await env.accounts.create(
          const NewAccount(
            kind: AccountKind.account,
            bankName: 'HDFC Bank',
            last4: '1234',
            accountType: AccountType.savings,
            balanceMinor: 5000000,
          ),
        );
      });

  // TC-13-14 (FR-13-04)
  testWidgets('empty list', (t) async {
    await pumpApp(t, env, _routes);
    expect(find.text('No accounts yet'), findsOneWidget);
    await teardownApp(t);
  });

  // TC-13-14 (FR-13-04, FR-13-07)
  for (final dark in [false, true]) {
    testWidgets('list shows account and balance (dark=$dark)', (t) async {
      await seed(t);
      await pumpApp(t, env, _routes, dark: dark);
      expect(find.text('HDFC Bank ••1234'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('account_balance_1'))).data,
        '₹50,000.00',
      );
      await teardownApp(t);
    });
  }

  // TC-13-14 (FR-13-05): add and duplicate error
  testWidgets('add account and reject duplicate', (t) async {
    await pumpApp(t, env, _routes);
    Future<void> add(String bank, String last4) async {
      await t.tap(find.byKey(const Key('accounts_add')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('add_bank')), bank);
      await t.enterText(find.byKey(const Key('add_last4')), last4);
      await t.tap(find.byKey(const Key('add_save')));
      await settle(t);
      await t.pumpAndSettle();
    }

    await add('ICICI Bank', '9876');
    expect(find.text('ICICI Bank ••9876'), findsOneWidget);
    await add('ICICI Bank', '9876');
    expect(find.byKey(const Key('add_error')), findsOneWidget);
    expect(find.text('Already in your list.'), findsOneWidget);
    await teardownApp(t);
  });

  // FR-13-06, FR-13-07: detail, rename, set balance
  testWidgets('detail: rename and set balance', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes, initial: '/accounts/1');
    expect(
      t.widget<Text>(find.byKey(const Key('detail_balance'))).data,
      '₹50,000.00',
    );
    Future<void> menu(String item) async {
      await t.tap(find.byKey(const Key('account_menu')));
      await t.pumpAndSettle();
      await t.tap(find.text(item));
      await t.pumpAndSettle();
    }

    await menu('Rename');
    await t.enterText(find.byKey(const Key('prompt_field')), 'Salary a/c');
    await t.tap(find.byKey(const Key('prompt_ok')));
    await settle(t);
    await t.pumpAndSettle();
    expect(find.text('Salary a/c'), findsOneWidget);

    await menu('Set balance');
    await t.enterText(find.byKey(const Key('prompt_field')), '1,200.50');
    await t.tap(find.byKey(const Key('prompt_ok')));
    await settle(t);
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('detail_balance'))).data,
      '₹1,200.50',
    );
    await teardownApp(t);
  });

  // FR-13-07: estimated flag after a later transaction
  testWidgets('detail: estimated balance flag', (t) async {
    await t.runAsync(() async {
      await env.settings.write(SettingKeys.hideAmounts, false);
      await env.ingest(parsed(balance: 5000000, ref: 'AAAAAA111'));
      await env.ingest(
        parsed(time: t0 + hour, ref: 'BBBBBB222'),
      );
    });
    await pumpApp(t, env, _routes, initial: '/accounts/1');
    expect(find.byKey(const Key('detail_estimated')), findsOneWidget);
    expect(find.text('Swiggy'), findsWidgets);
    await teardownApp(t);
  });

  // FR-13-10: hide then show again
  testWidgets('hide moves to hidden, show again restores', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes);
    await t.tap(find.byKey(const Key('account_1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('account_menu')));
    await t.pumpAndSettle();
    await t.tap(find.text('Hide'));
    await settle(t);
    await t.pumpAndSettle();
    expect(find.text('Hidden (1)'), findsOneWidget);
    await t.tap(find.text('Show again'));
    await settle(t);
    expect(find.text('Hidden (1)'), findsNothing);
    expect(find.byKey(const Key('account_1')), findsOneWidget);
    await teardownApp(t);
  });

  // FR-13-11: delete needs confirmation
  testWidgets('delete confirms first', (t) async {
    await seed(t);
    await pumpApp(t, env, _routes);
    await t.tap(find.byKey(const Key('account_1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('account_menu')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(await t.runAsync(() => env.accounts.byId(1)), isNotNull);
    await t.tap(find.byKey(const Key('account_menu')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('delete_confirm')));
    await settle(t);
    await t.pumpAndSettle();
    expect(await t.runAsync(() => env.accounts.byId(1)), isNull);
    expect(find.text('No accounts yet'), findsOneWidget);
    await teardownApp(t);
  });

  // FR-13-21
  testWidgets('groups accounts and filters by the global book', (t) async {
    await t.runAsync(() async {
      await env.settings.write(SettingKeys.hideAmounts, false);
      await env.accounts.create(
        const NewAccount(
          kind: AccountKind.account,
          bankName: 'HDFC Bank',
          last4: '1234',
          accountType: AccountType.savings,
          balanceMinor: 5000000,
        ),
      );
      await env.accounts.create(
        const NewAccount(
          kind: AccountKind.account,
          bankName: 'Paytm',
          last4: '0001',
          accountType: AccountType.wallet,
          balanceMinor: 100000,
          usage: AccountUsage.business,
        ),
      );
      await env.accounts.create(
        const NewAccount(
          kind: AccountKind.card,
          bankName: 'ICICI Bank',
          last4: '9876',
          accountType: AccountType.creditCard,
        ),
      );
    });
    await pumpApp(t, env, _routes);
    expect(find.text('Bank accounts'), findsOneWidget);
    expect(find.text('Cash and wallets'), findsOneWidget);
    expect(find.text('Credit cards'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    final container = ProviderScope.containerOf(
      t.element(find.byType(AccountsManagementScreen)),
    );
    container.read(bookProvider.notifier).set(Book.business);
    await settle(t);
    expect(find.text('Bank accounts'), findsNothing);
    expect(find.text('Cash and wallets'), findsOneWidget);
    expect(find.text('Credit cards'), findsNothing);
    await teardownApp(t);
  });
}

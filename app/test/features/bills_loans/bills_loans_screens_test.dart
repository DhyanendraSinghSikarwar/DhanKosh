// Bills and Loans screens (FR-12-03, 04, 06, 09, 10; FR-15-04..07, 10, 11).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/sip_providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/loans/data/loan_account_repository_impl.dart';
import 'package:hisaab/features/loans/data/loan_link_repository_impl.dart';
import 'package:hisaab/features/loans/domain/loan_account_repository.dart';
import 'package:hisaab/features/loans/presentation/loan_detail_screen.dart';
import 'package:hisaab/features/loans/presentation/loans_screen.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/data/recurring_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/data/sip_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/presentation/recurring_transactions_screen.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<void> s(WidgetTester t) async {
    await settle(t);
    await t.pump(const Duration(milliseconds: 600));
  }

  Future<void> pump(WidgetTester t, {bool dark = false}) async {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/bills',
          builder: (_, __) => const RecurringTransactionsScreen(),
        ),
        GoRoute(
          path: '/loans',
          builder: (_, __) => const LoansScreen(),
          routes: [
            GoRoute(
              path: ':key',
              builder: (_, s) =>
                  LoanDetailScreen(loanKey: s.pathParameters['key']!),
            ),
          ],
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(env.accounts),
          transactionRepositoryProvider.overrideWithValue(env.txs),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          recurringRepositoryProvider
              .overrideWithValue(RecurringRepositoryImpl(env.db)),
          sipRepositoryProvider.overrideWithValue(SipRepositoryImpl(env.db)),
          holdingRepositoryProvider
              .overrideWithValue(HoldingRepositoryImpl(env.db)),
          loanLinkRepositoryProvider
              .overrideWithValue(LoanLinkRepositoryImpl(env.db)),
          loanAccountRepositoryProvider
              .overrideWithValue(LoanAccountRepositoryImpl(env.db)),
          hideAmountsProvider.overrideWith((_) => Stream.value(false)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
        ),
      ),
    );
    router.go('/');
    await s(t);
  }

  Future<void> go(WidgetTester t, String path) async {
    final ctx = t.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).go(path);
    await s(t);
  }

  testWidgets('bills empty state', (t) async {
    await pump(t);
    await go(t, '/bills');
    expect(find.text('Nothing found yet'), findsOneWidget);
    await teardownApp(t);
  });

  for (final dark in [false, true]) {
    testWidgets('bills populated (dark: $dark), add manual, confirm detected',
        (t) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var m = 1; m <= 3; m++) {
        await env.ingest(
          parsed(
            amountMinor: 49900,
            merchant: 'Netflix',
            ref: 'n$m',
            time: now - m * 30 * 86400000,
            category: Category.subscriptions,
          ),
        );
      }
      await pump(t, dark: dark);
      await go(t, '/bills');
      expect(find.byKey(const Key('bill-Netflix')), findsOneWidget);
      expect(find.textContaining('Detected'), findsOneWidget);
      expect(find.byKey(const Key('sum-month')), findsOneWidget);

      // Add a manual yearly item (FR-12-03).
      await t.tap(find.byKey(const Key('bills-add')));
      await s(t);
      await t.enterText(find.byKey(const Key('rec-name')), 'Gym');
      await t.enterText(find.byKey(const Key('rec-amount')), '12000');
      await t.enterText(find.byKey(const Key('rec-day')), '10');
      await t.tap(find.byKey(const Key('rec-save')));
      await s(t);
      expect(find.byKey(const Key('bill-Gym')), findsOneWidget);

      // Confirm the detected item: stored, so it is no longer "Detected".
      await t.tap(find.byKey(const Key('bill-Netflix')));
      await s(t);
      await t.tap(find.byKey(const Key('rec-save')));
      await s(t);
      expect(find.textContaining('Detected'), findsNothing);
      expect(await RecurringRepositoryImpl(env.db).all(), hasLength(2));
      await teardownApp(t);
    });
  }

  testWidgets('bills validation and delete', (t) async {
    await pump(t);
    final repo = RecurringRepositoryImpl(env.db);
    await repo.add(
      const RecurringDraft(
        name: 'Rent',
        amountMinor: 1500000,
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        category: Category.rent,
      ),
    );
    await go(t, '/bills');
    await t.tap(find.byKey(const Key('bills-add')));
    await s(t);
    await t.tap(find.byKey(const Key('rec-save')));
    await s(t);
    expect(find.byKey(const Key('rec-error')), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await s(t);
    await t.tap(find.byKey(const Key('bill-Rent')));
    await s(t);
    await t.tap(find.byKey(const Key('rec-delete')));
    await s(t);
    expect(await repo.all(), isEmpty);
    await teardownApp(t);
  });

  testWidgets('loans empty, add manual, detail schedule', (t) async {
    await pump(t);
    await go(t, '/loans');
    expect(find.text('No loans yet'), findsOneWidget);
    await t.tap(find.byKey(const Key('loans-add')));
    await s(t);
    await t.tap(find.byKey(const Key('loan-save')));
    await s(t);
    expect(find.byKey(const Key('loan-error')), findsOneWidget);
    await t.enterText(find.byKey(const Key('loan-lender')), 'Demo Bank');
    await t.enterText(find.byKey(const Key('loan-principal')), '120000');
    await t.enterText(find.byKey(const Key('loan-rate')), '12');
    await t.enterText(find.byKey(const Key('loan-tenure')), '12');
    await t.tap(find.byKey(const Key('loan-save')));
    await s(t);
    expect(find.text('Demo Bank'), findsOneWidget);
    await t.tap(find.text('Demo Bank'));
    await s(t);
    expect(find.byKey(const Key('loan-remaining')), findsOneWidget);
    await t.tap(find.byKey(const Key('loan-schedule')));
    await s(t);
    expect(find.byKey(const Key('inst-1')), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('loans detected: dismiss and undo (FR-15-11)', (t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var m = 0; m < 3; m++) {
      await env.ingest(
        parsed(
          amountMinor: 1200000,
          merchant: 'Demo Finance',
          ref: 'e$m',
          time: now - (m * 30 + 3) * 86400000,
          category: Category.emiLoan,
        ),
      );
    }
    await pump(t, dark: true);
    await go(t, '/loans');
    expect(find.text('Demo Finance'), findsOneWidget);
    await t.tap(find.text('Demo Finance'));
    await s(t);
    await t.tap(find.byKey(const Key('loan-dismiss')));
    await s(t);
    expect(find.text('No loans yet'), findsNothing);
    expect(find.byKey(const Key('dismissed-demo finance')), findsOneWidget);
    await t.tap(find.text('Undo'));
    await s(t);
    expect(find.text('Demo Finance'), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('link and unlink a payment (FR-15-10)', (t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await LoanAccountRepositoryImpl(env.db).create(
      const LoanDraft(
        bankName: 'Demo Bank',
        principalMinor: 12000000,
        rateBps: 1200,
        tenureMonths: 12,
      ),
    );
    final r = await env.ingest(
      parsed(
        amountMinor: 1066000,
        merchant: 'Acme Lender',
        ref: 'l1',
        time: now - 86400000,
        category: Category.emiLoan,
      ),
    );
    await pump(t);
    await go(t, '/loans/${Uri.encodeComponent('acct:$id')}');
    await t.tap(find.byKey(const Key('loan-link')));
    await s(t);
    await t.tap(find.textContaining('Acme Lender'));
    await s(t);
    final txId =
        (await t.runAsync(() => env.txs.watchRecent(5).first))!.first.id;
    expect(r, isNotNull);
    expect(find.byKey(Key('unlink-$txId')), findsOneWidget);
    await t.tap(find.byKey(Key('unlink-$txId')));
    await s(t);
    expect(find.byKey(Key('unlink-$txId')), findsNothing);
    await teardownApp(t);
  });
}

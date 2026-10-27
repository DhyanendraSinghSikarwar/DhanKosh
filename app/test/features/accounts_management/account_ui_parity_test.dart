import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/untracked_gap_service.dart';
import 'package:hisaab/features/accounts_management/presentation/account_detail_screen.dart';
import 'package:hisaab/features/accounts_management/presentation/account_edit_sheet.dart';
import 'package:hisaab/features/accounts_management/presentation/accounts_management_screen.dart';
import 'package:hisaab/features/dedup_review/presentation/compare_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

final _routes = <RouteBase>[
  GoRoute(path: '/', builder: (_, __) => const AccountsManagementScreen()),
  GoRoute(
    path: '/accounts/:id',
    builder: (_, s) =>
        AccountDetailScreen(accountId: int.parse(s.pathParameters['id']!)),
  ),
];

const int _day = 24 * 60 * 60 * 1000;

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  // Gap fixture: 19,001 stated, a Rs 1,000 payment nobody told us about,
  // 18,001 stated four days later (credit of Rs 1 in between => gap -1,000).
  Future<int> seedGap(WidgetTester t) async => (await t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, false);
        final now = DateTime.now().millisecondsSinceEpoch;
        final a = await env.ingest(
          parsed(
            amountMinor: 100,
            type: TransactionType.credit,
            balance: 1900100,
            time: now - 10 * _day,
            ref: 'r1',
            merchant: 'Refund',
          ),
        );
        await env.ingest(
          parsed(
            amountMinor: 100,
            type: TransactionType.credit,
            balance: 1800200,
            time: now - 6 * _day,
            ref: 'r2',
            merchant: 'Refund two',
          ),
        );
        return (await env.txs.byId(a.transactionId!))!.accountId!;
      }))!;

  // TC-13-17 (FR-13-15): gap card, Ignore persists.
  testWidgets('gap card ignore is persisted', (t) async {
    final id = await seedGap(t);
    await pumpApp(t, env, _routes, initial: '/accounts/$id');
    expect(find.byKey(const Key('gap_summary')), findsOneWidget);
    expect(find.textContaining('left'), findsWidgets);
    await t.tap(find.byKey(const Key('gap_ignore')));
    await settle(t);
    expect(find.byKey(const Key('gap_summary')), findsNothing);
    final dismissed = await t.runAsync(
      () => env.settings.read(GapSettingKeys.dismissed),
    );
    expect(dismissed, hasLength(1));
    await teardownApp(t);
  });

  // TC-13-11, TC-13-17 (FR-13-15): Add transaction explains the gap.
  testWidgets('gap Add transaction records a payment and clears the gap',
      (t) async {
    t.view.physicalSize = const Size(800, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final id = await seedGap(t);
    await pumpApp(t, env, _routes, initial: '/accounts/$id');
    await settle(t);
    await settle(t);
    await t.tap(find.byKey(const Key('gap_add')));
    await t.pumpAndSettle();
    await settle(t);
    expect(find.byKey(const Key('gap_choice_payment')), findsOneWidget);
    expect(find.byKey(const Key('gap_choice_received')), findsNothing);
    await t.enterText(find.byKey(const Key('gap_what')), 'Rent');
    await t.tap(find.byKey(const Key('gap_save')));
    await settle(t);
    final rows = await t.runAsync(
      () => env.txs.watch(const LedgerFilter()).first,
    );
    expect(
      rows!.where((r) => r.merchant == 'Rent' && r.amountMinor == 100000),
      hasLength(1),
    );
    expect(find.byKey(const Key('gap_summary')), findsNothing);
    final last = await t.runAsync(
      () => UntrackedGapService(
        accounts: env.adminForTest,
        transactions: env.txs,
        settings: env.settings,
      ).lastChoice(id),
    );
    expect(last, isNotNull);
    await teardownApp(t);
  });

  // TC-13-17 (FR-13-17): chart range switch and totals.
  testWidgets('detail chart shows totals and switches range', (t) async {
    final id = await seedGap(t);
    await pumpApp(t, env, _routes, initial: '/accounts/$id');
    await t.scrollUntilVisible(
      find.byKey(const Key('series_range')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('series_income')), findsOneWidget);
    await t.tap(find.text('All time'));
    await settle(t);
    expect(find.byKey(const Key('series_spent')), findsOneWidget);
    await teardownApp(t);
  });

  // TC-13-15 (FR-13-06): nickname, colour, network, markup.
  testWidgets('edit sheet saves personalisation and validates markup',
      (t) async {
    t.view.physicalSize = const Size(800, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final card = await t.runAsync(
      () => env.accounts.create(
        const NewAccount(
          kind: AccountKind.card,
          bankName: 'HDFC Bank',
          last4: '5678',
          accountType: AccountType.creditCard,
        ),
      ),
    );
    await pumpApp(t, env, _routes, initial: '/accounts/$card');
    await t.tap(find.byKey(const Key('account_menu')));
    await t.pumpAndSettle();
    await t.tap(find.text('Edit'));
    await t.pumpAndSettle();
    await t.pumpAndSettle();
    await settle(t);
    await t.enterText(find.byKey(const Key('edit_nickname')), 'Travel card');
    await t.tap(find.byKey(const Key('edit_network_visa')));
    await t.tap(find.byKey(const Key('edit_color_${0xFF43A047}')));
    await t.enterText(find.byKey(const Key('edit_markup')), '25');
    await t.tap(find.byKey(const Key('edit_save')));
    await settle(t);
    expect(find.byKey(const Key('edit_error')), findsOneWidget);
    await t.enterText(find.byKey(const Key('edit_markup')), '3.5');
    await t.tap(find.byKey(const Key('edit_save')));
    await settle(t);
    final a = await t.runAsync(() => env.accounts.byId(card!));
    expect(a!.nickname, 'Travel card');
    expect(a.cardNetwork, CardNetwork.visa);
    expect(a.colorArgb, 0xFF43A047);
    expect(await t.runAsync(() => env.adminForTest.forexMarkupBps(card!)), 350);
    await teardownApp(t);
  });

  // TC-13-16 (FR-13-09, FR-13-08): duplicate suggestion, merge, unmerge.
  testWidgets('duplicate suggestion merges and unmerge restores', (t) async {
    final ids = await t.runAsync(() async {
      final a = await env.accounts.create(
        const NewAccount(
          kind: AccountKind.account,
          bankName: 'ICICI Bank',
          last4: '1234',
        ),
      );
      final b = await env.accounts.create(
        const NewAccount(
          kind: AccountKind.account,
          bankName: 'ICICI Bank',
          last4: '234',
        ),
      );
      return [a!, b!];
    });
    await pumpApp(t, env, _routes);
    expect(find.text('Possible duplicate account'), findsOneWidget);
    await t.tap(find.text('Not duplicates'));
    await settle(t);
    expect(find.text('Possible duplicate account'), findsNothing);
    await teardownApp(t);

    await pumpApp(t, env, _routes);
    await t.tap(find.text('Merge'));
    await settle(t);
    final b = await t.runAsync(() => env.accounts.byId(ids![1]));
    expect(b!.mergedIntoId, ids![0]);
    expect(find.byKey(Key('account_${ids[1]}')), findsNothing);
    await t.runAsync(() => env.adminForTest.unmerge(ids[1]));
    await settle(t);
    expect(find.byKey(Key('account_${ids[1]}')), findsOneWidget);
    await teardownApp(t);
  });

  // TC-13-19 (FR-13-12): restore missing accounts.
  testWidgets('restore missing accounts re-attaches orphans', (t) async {
    final txId = await t.runAsync(() async {
      final r = await env.ingest(parsed(ref: 'rx'));
      final tx = (await env.txs.byId(r.transactionId!))!;
      await env.accounts.delete(tx.accountId!);
      return tx.id;
    });
    await pumpApp(t, env, _routes);
    await t.tap(find.byKey(const Key('accounts_menu')));
    await t.pumpAndSettle();
    await t.tap(find.text('Restore missing accounts'));
    await t.pumpAndSettle();
    await settle(t);
    await t.pump();
    expect(find.text('Restored 1 accounts'), findsOneWidget);
    final tx = await t.runAsync(() => env.txs.byId(txId!));
    expect(tx!.accountId, isNotNull);
    await teardownApp(t);
  });

  // FR-07-13: compare highlights only the differences.
  testWidgets('compare screen highlights differing fields', (t) async {
    LedgerTx row(int id, String merchant) => LedgerTx(
          id: id,
          amountMinor: 25000,
          currency: 'INR',
          type: TransactionType.debit,
          bankName: 'HDFC Bank',
          accountKind: AccountKind.account,
          channel: Channel.upi,
          timestamp: t0,
          hasExplicitTime: true,
          category: Category.food,
          transactionHash: 'h$id',
          confidence: 1,
          needsReview: id == 1,
          createdAt: 0,
          merchant: merchant,
          reviewReason: 'Same amount within 2 hours',
        );
    await pumpApp(t, env, [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            CompareScreen(ReviewPair(row(1, 'Swiggy'), row(2, 'Zomato'))),
      ),
    ]);
    final merchant =
        t.widget<Container>(find.byKey(const Key('diff_Merchant')));
    final amount = t.widget<Container>(find.byKey(const Key('diff_Amount')));
    expect(merchant.color, isNotNull);
    expect(amount.color, isNull);
    expect(find.text('Merge'), findsOneWidget);
    expect(find.text('Keep separate'), findsOneWidget);
    await teardownApp(t);
  });
}

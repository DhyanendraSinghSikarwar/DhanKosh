import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/ledger_shell.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/presentation/add_transaction_screen.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

void tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  final at = DateTime(2026, 10, 20, 9, 30);
  FakeTxRepo repo() => FakeTxRepo([
        fakeTx(1, 45000, at, merchant: 'Swiggy', upiId: 'swiggy@icici'),
      ])
        ..sources = [
          TxSourceRow(
            id: 1,
            transactionId: 1,
            source: Source.sms,
            sourceMessageId: 'm1',
            sender: 'HDFCBK',
            parsedHash: 'h1',
            receivedAt: at.millisecondsSinceEpoch,
            rawText: 'Rs 450 debited to Swiggy',
          ),
        ];

  testWidgets('FR-08-10: detail shows fields and source message', (t) async {
    tall(t);
    await pumpLedgerApp(
      t,
      txs: repo(),
      home: const TransactionDetailRoute(id: 1),
    );
    await t.pump();
    await t.pump();
    expect(find.text('Swiggy'), findsOneWidget);
    expect(find.byKey(const Key('detail_amount')), findsOneWidget);
    expect(find.text('-₹450.00'), findsOneWidget);
    expect(find.text('swiggy@icici'), findsOneWidget);
    expect(find.text('SMS · HDFCBK'), findsOneWidget);
    expect(find.text('Rs 450 debited to Swiggy'), findsOneWidget);
  });

  testWidgets('FR-09-05, FR-09-08, FR-09-09: change category and save rule',
      (t) async {
    tall(t);
    final txs = repo();
    final cats = FakeCategoryRepo();
    await pumpLedgerApp(
      t,
      txs: txs,
      categories: cats,
      home: const TransactionDetailRoute(id: 1),
    );
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('detail_category')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cat_food')));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('rule_save')));
    await t.tap(find.byKey(const Key('rule_save')));
    await t.pumpAndSettle();
    expect(find.text('Also apply to past (3)'), findsOneWidget);
    await t.tap(find.byKey(const Key('rule_past')));
    await t.pump();
    await t.tap(find.byKey(const Key('category_save')));
    await t.pumpAndSettle();

    expect(txs.categorySets.single.$1, [1]);
    expect(txs.categorySets.single.$2, Category.food);
    expect(cats.saved.single.merchantKey, 'swiggy');
    expect(cats.saved.single.manual, isTrue);
    expect(cats.saved.single.category, Category.food);
    expect(txs.applied, hasLength(1));
    expect(find.text('Food & Dining'), findsOneWidget);
  });

  testWidgets('FR-09-05: plain change does not save a rule', (t) async {
    tall(t);
    final txs = repo();
    final cats = FakeCategoryRepo();
    await pumpLedgerApp(
      t,
      txs: txs,
      categories: cats,
      home: const TransactionDetailRoute(id: 1),
    );
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('detail_category')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cat_groceries')));
    await t.tap(find.byKey(const Key('category_save')));
    await t.pumpAndSettle();
    expect(txs.categorySets.single.$2, Category.groceries);
    expect(cats.saved, isEmpty);
    expect(txs.applied, isEmpty);
  });

  testWidgets('FR-08-10: edit note', (t) async {
    tall(t);
    final txs = repo();
    await pumpLedgerApp(
      t,
      txs: txs,
      home: const TransactionDetailRoute(id: 1),
    );
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('detail_note')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('note_field')), 'lunch');
    await t.tap(find.byKey(const Key('note_save')));
    await t.pumpAndSettle();
    expect(txs.notes.single, (1, 'lunch'));
  });

  testWidgets('FR-08-09: delete asks for confirmation', (t) async {
    tall(t);
    final txs = repo();
    await pumpLedgerApp(
      t,
      txs: txs,
      home: const Text('list'),
      routes: [
        GoRoute(
          path: '/transaction/:id',
          builder: (_, __) => const TransactionDetailRoute(id: 1),
        ),
      ],
    );
    unawaited(
      GoRouter.of(t.element(find.text('list'))).push<void>('/transaction/1'),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('detail_delete')));
    await t.pumpAndSettle();
    expect(find.text('Delete 1 transaction?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(txs.deleted, isEmpty);
    await t.tap(find.byKey(const Key('detail_delete')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('delete_confirm')));
    await t.pumpAndSettle();
    expect(txs.deleted, [1]);
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('FR-08-11: manual add saves paise', (t) async {
    tall(t);
    final txs = repo();
    await pumpLedgerApp(t, txs: txs, home: const AddTransactionScreen());
    await t.tap(find.byKey(const Key('add_save')));
    await t.pump();
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(txs.manual, isEmpty);

    await t.enterText(find.byKey(const Key('add_amount')), '1,250.50');
    await t.enterText(find.byKey(const Key('add_payee')), 'Chai Point');
    await t.tap(find.text('Received'));
    await t.pump();
    await t.tap(find.byKey(const Key('add_save')));
    await t.pumpAndSettle();
    final m = txs.manual.single;
    expect(m['amountMinor'], 125050);
    expect(m['type'], TransactionType.credit);
    expect(m['merchant'], 'Chai Point');
  });

  // FR-08-10: sub-category and account edit.
  testWidgets('FR-08-10: edit sub-category and account', (t) async {
    tall(t);
    final r = repo();
    await pumpLedgerApp(
      t,
      txs: r,
      accounts: FakeAccountRepo([
        const Account(
          id: 7,
          bankName: 'ICICI Bank',
          last4: '4321',
          kind: AccountKind.account,
          createdAt: 0,
        ),
      ]),
      home: const TransactionDetailRoute(id: 1),
    );
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('detail_subcategory')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('sub_field')), 'Dinner');
    await t.tap(find.byKey(const Key('sub_save')));
    await t.pumpAndSettle();
    expect(r.subs.single, (1, 'Dinner'));
    await t.tap(find.byKey(const Key('detail_account')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('acct_7')));
    await t.pumpAndSettle();
    expect(r.accountSets.single, (1, 7));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/app/ledger_shell.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/search_filters/presentation/ledger_view_notifier.dart';
import 'package:hisaab/features/transactions_ledger/presentation/add_transaction_screen.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 10);
  const accounts = [
    Account(
      id: 1,
      bankName: 'HDFC Bank',
      last4: '1111',
      kind: AccountKind.account,
      createdAt: 0,
    ),
    Account(
      id: 2,
      bankName: 'ICICI Bank',
      last4: '2222',
      kind: AccountKind.card,
      createdAt: 0,
    ),
  ];

  testWidgets('FR-08-25: Transfer mode writes both legs', (t) async {
    final repo = FakeTxRepo([]);
    await pumpLedgerApp(
      t,
      txs: repo,
      accounts: FakeAccountRepo(accounts),
      home: const AddTransactionScreen(),
    );
    await t.tap(find.text('Transfer'));
    await t.pump();
    expect(find.byKey(const Key('add_payee')), findsNothing);
    await t.enterText(find.byKey(const Key('add_amount')), '500.25');
    await t.tap(find.byKey(const Key('add_account')));
    await t.pumpAndSettle();
    await t.tap(find.text('HDFC Bank ••1111').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add_to_account')));
    await t.pumpAndSettle();
    await t.tap(find.text('ICICI Bank ••2222').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('add_save')));
    await t.pumpAndSettle();
    expect(repo.ownTransfers.single, (1, 2, 50025));
  });

  testWidgets('FR-08-23, FR-10-18: By category with card tag and strip',
      (t) async {
    final repo = FakeTxRepo([
      fakeTx(1, 40000, today, merchant: 'Swiggy', category: Category.food),
      fakeTx(
        2,
        60000,
        today,
        merchant: 'Zomato',
        category: Category.food,
        kind: AccountKind.card,
      ),
    ]);
    await pumpLedgerApp(t, txs: repo, home: const TransactionsTab());
    await t.pump();
    await t.pump();
    // Headline leaves the card purchase out and says so.
    await t.tap(find.byKey(const Key('sum_info')));
    await t.pump();
    expect(find.byKey(const Key('sum_card')), findsOneWidget);
    expect(find.byKey(const Key('sum_basis')), findsOneWidget);
    expect(
      t.widget<Text>(find.byKey(const Key('sum_spent'))).data,
      contains('400'),
    );
    expect(find.textContaining('· Card'), findsWidgets);
    await t.tap(find.byKey(const Key('ledger_view_dropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('By category').last);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('category_bar_food')), findsOneWidget);
    await t.tap(find.byKey(const Key('category_food')));
    await t.pumpAndSettle();
    final split = t.widget<Text>(find.byKey(const Key('category_split_food')));
    expect(split.data, contains('Account'));
    expect(split.data, contains('Card'));
  });

  testWidgets('FR-08-23: source dropdown filters, book tag follows Book',
      (t) async {
    await pumpLedgerApp(
      t,
      txs: FakeTxRepo([fakeTx(1, 100, today)]),
      home: const TransactionsTab(),
    );
    await t.pump();
    expect(find.byKey(const Key('acckind_card')), findsNothing);
    expect(find.byKey(const Key('book_business')), findsNothing);
    // The tag shows only for Business, so the default All books has none.
    expect(find.text('All books'), findsNothing);
    await t.tap(find.byKey(const Key('source_dropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('Cards').last);
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('source_dropdown')),
        matching: find.text('Cards'),
      ),
      findsOneWidget,
    );
    final c =
        ProviderScope.containerOf(t.element(find.byType(TransactionsTab)));
    expect(c.read(ledgerViewProvider).accountKind, AccountKind.card);
    await t.tap(find.byKey(const Key('period_thisFy')));
    await t.pump();
    expect(
      t.widget<ChoiceChip>(find.byKey(const Key('period_thisFy'))).selected,
      isTrue,
    );
  });

  testWidgets('FR-20-23: no book tag for Personal', (t) async {
    await pumpLedgerApp(
      t,
      txs: FakeTxRepo([fakeTx(1, 100, today)]),
      home: const TransactionsTab(),
    );
    await t.pump();
    final c =
        ProviderScope.containerOf(t.element(find.byType(TransactionsTab)));
    c.read(bookProvider.notifier).set(Book.personal);
    await t.pump();
    expect(find.byKey(const Key('book_tag')), findsNothing);
    c.read(bookProvider.notifier).set(Book.business);
    await t.pump();
    expect(find.text('Business'), findsOneWidget);
  });

  testWidgets('FR-08-24: remember payee checkbox', (t) async {
    final repo = FakeTxRepo([
      fakeTx(1, 100, today, merchant: 'Chai'),
    ]);
    await pumpLedgerApp(
      t,
      txs: repo,
      accounts: FakeAccountRepo(accounts),
      home: const TransactionDetailRoute(id: 1),
    );
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('detail_account')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('acct_remember')));
    await t.pump();
    await t.tap(find.byKey(const Key('acct_1')));
    await t.pumpAndSettle();
    expect(repo.remembered, [1]);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_views.dart';
import 'package:hisaab/features/transactions_ledger/presentation/transactions_ledger_screen.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

void main() {
  final d1 = DateTime(2026, 9, 5, 10);
  final d2 = DateTime(2026, 9, 12, 10);
  final rows = [
    fakeTx(1, 50000, d2, merchant: 'Swiggy'),
    fakeTx(2, 25000, d1, merchant: 'Swiggy'),
    fakeTx(3, 900000, d1, merchant: 'ACME', type: TransactionType.credit),
    fakeTx(4, 70000, d1, merchant: 'Uber'),
  ];

  // FR-08-03, FR-08-21
  test('dayValues sums spends for ALL; income for income', () {
    final all = dayValues(rows, TxKind.all);
    expect(all[DateTime(2026, 9, 5)], 95000);
    expect(all[DateTime(2026, 9, 12)], 50000);
    final credits = rows.where((r) => r.type == TransactionType.credit);
    expect(dayValues(credits, TxKind.income)[DateTime(2026, 9, 5)], 900000);
    expect(calendarCaption(TxKind.review), 'Flagged amounts by day');
    expect(calendarCaption(TxKind.all), 'Daily spend');
  });

  // FR-08-04
  test('groupByMerchant sorts by gross', () {
    final g = groupByMerchant(rows);
    expect(g.first.name, 'ACME');
    expect(g[1].name, 'Swiggy');
    expect(g[1].grossMinor, 75000);
  });

  Future<void> pump(WidgetTester t, FakeTxRepo repo) => pumpLedgerApp(
        t,
        txs: repo,
        home: TransactionsLedgerScreen(
          filter: LedgerFilter(
            fromMs: DateTime(2026, 9).millisecondsSinceEpoch,
            toMs: DateTime(2026, 10).millisecondsSinceEpoch,
          ),
          periodLabel: 'Sep',
          pickCategory: (_, __) async => null,
        ),
      );

  testWidgets('FR-08-03/04: calendar and merchant segments', (t) async {
    await pump(t, FakeTxRepo(rows));
    await t.pump();
    await t.tap(find.byKey(const Key('ledger_view_dropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('Calendar').last);
    await t.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.byKey(const Key('cal_caption')), findsOneWidget);
    await t.tap(find.byKey(const Key('cal_day_5')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tx-4')), findsOneWidget);
    expect(find.byKey(const Key('tx-1')), findsNothing);
    // Period honoured: no earlier or later month.
    expect(
      t.widget<IconButton>(find.byKey(const Key('cal_prev'))).onPressed,
      isNull,
    );
    await t.tap(find.byKey(const Key('ledger_view_dropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('Merchant').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('merchant_Swiggy')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tx-1')), findsOneWidget);
  });

  testWidgets('FR-08-08: long press selects, bulk delete confirms', (t) async {
    final repo = FakeTxRepo(rows);
    await pump(t, repo);
    await t.pump();
    await t.longPress(find.byKey(const Key('tx-1')));
    await t.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await t.tap(find.byKey(const Key('tx-2')));
    await t.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await t.tap(find.byKey(const Key('sel_delete')));
    await t.pumpAndSettle();
    expect(find.text('Delete 2 transactions?'), findsOneWidget);
    await t.tap(find.byKey(const Key('bulk_delete_confirm')));
    await t.pumpAndSettle();
    expect(repo.deleted, containsAll([1, 2]));
    expect(find.text('Transactions'), findsOneWidget);
  });

  testWidgets('FR-08-08: select all and merge', (t) async {
    final repo = FakeTxRepo(rows);
    await pump(t, repo);
    await t.pump();
    await t.longPress(find.byKey(const Key('tx-1')));
    await t.pump();
    await t.tap(find.byKey(const Key('sel_all')));
    await t.pump();
    expect(find.text('4 selected'), findsOneWidget);
    await t.tap(find.byKey(const Key('sel_merge')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('bulk_merge_confirm')));
    await t.pumpAndSettle();
    expect(repo.mergedRows.single.length, 4);
  });
}

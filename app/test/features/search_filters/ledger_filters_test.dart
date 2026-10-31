import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/ledger_shell.dart';
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

void main() {
  test('FR-20-05: period ranges', () {
    final now = DateTime(2026, 10, 21, 15);
    final m = periodRange(PeriodKind.thisMonth, now);
    expect(m.fromMs, DateTime(2026, 10).millisecondsSinceEpoch);
    expect(m.toMs, DateTime(2026, 11).millisecondsSinceEpoch);
    final l = periodRange(PeriodKind.lastMonth, DateTime(2026, 1, 5));
    expect(l.fromMs, DateTime(2025, 12).millisecondsSinceEpoch);
    expect(l.toMs, DateTime(2026).millisecondsSinceEpoch);
    // FR-20-04: missing end equals start, inclusive.
    final c = periodRange(
      PeriodKind.custom,
      now,
      customStart: DateTime(2026, 10, 3),
    );
    expect(c.toMs! - c.fromMs!, const Duration(days: 1).inMilliseconds);
    expect(periodRange(PeriodKind.all, now).fromMs, isNull);
  });

  test('FR-20-16: cleared keeps query and period', () {
    const s = LedgerViewState(
      kind: TxKind.income,
      period: PeriodKind.lastMonth,
      query: 'swiggy',
      accountId: 2,
      category: Category.food,
    );
    final c = s.cleared();
    expect(c.hasChipFilters, isFalse);
    expect(c.query, 'swiggy');
    expect(c.period, PeriodKind.lastMonth);
    expect(s.toFilter(DateTime(2026, 10, 21)).query, 'swiggy');
  });

  group('tab', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10);
    final lastMonth = DateTime(now.year, now.month - 1, 15, 10);
    FakeTxRepo repo() => FakeTxRepo([
          fakeTx(1, 50000, today, merchant: 'Swiggy', category: Category.food),
          fakeTx(
            2,
            100000,
            today,
            type: TransactionType.credit,
            merchant: 'ACME Payroll',
          ),
          fakeTx(3, 7000, lastMonth, merchant: 'Uber'),
        ]);

    testWidgets('FR-08-05, FR-20-13: type chips filter', (t) async {
      await pumpLedgerApp(t, txs: repo(), home: const TransactionsTab());
      await t.pump();
      expect(find.byKey(const Key('tx-1')), findsOneWidget);
      expect(find.byKey(const Key('tx-2')), findsOneWidget);
      expect(find.byKey(const Key('tx-3')), findsNothing);
      await t.tap(find.byKey(const Key('ledger_filter_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('kind_income')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('tx-1')), findsNothing);
      expect(find.byKey(const Key('tx-2')), findsOneWidget);
      await t.tap(find.byKey(const Key('filters_clear')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('tx-1')), findsOneWidget);
      expect(find.byKey(const Key('ledger_filter_badge')), findsOneWidget);
    });

    testWidgets('FR-20-03: period chips', (t) async {
      await pumpLedgerApp(t, txs: repo(), home: const TransactionsTab());
      await t.tap(find.byKey(const Key('period_lastMonth')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('tx-3')), findsOneWidget);
      expect(find.byKey(const Key('tx-1')), findsNothing);
      await t.tap(find.byKey(const Key('sum_info')));
      await t.pump();
      expect(find.text('1 transactions · Last month'), findsOneWidget);
    });

    testWidgets('FR-20-11, FR-20-19: debounced search, badge, clear',
        (t) async {
      await pumpLedgerApp(t, txs: repo(), home: const TransactionsTab());
      await t.pump();
      expect(find.byKey(const Key('ledger_search')), findsNothing);
      await t.tap(find.byKey(const Key('ledger_search_toggle')));
      await t.pump();
      await t.enterText(find.byKey(const Key('ledger_search')), 'swig');
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('tx-2')), findsOneWidget); // not yet
      await t.pump(const Duration(milliseconds: 150));
      await t.pump();
      expect(find.byKey(const Key('tx-1')), findsOneWidget);
      expect(find.byKey(const Key('tx-2')), findsNothing);
      expect(
        t
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('ledger_match_count')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '1',
      );
      await t.enterText(find.byKey(const Key('ledger_search')), 'nomatch');
      await t.pump(const Duration(milliseconds: 200));
      await t.pump();
      expect(
        find.text('Nothing matches “nomatch” in this month.'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('ledger_search_clear')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('tx-2')), findsOneWidget);
    });

    testWidgets('FR-08-07: category filter menu', (t) async {
      await pumpLedgerApp(t, txs: repo(), home: const TransactionsTab());
      await t.tap(find.byKey(const Key('ledger_filter_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('category_filter')));
      await t.pumpAndSettle();
      await t.tap(find.text('Food & Dining').last);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('tx-1')), findsOneWidget);
      expect(find.byKey(const Key('tx-2')), findsNothing);
    });
  });
}

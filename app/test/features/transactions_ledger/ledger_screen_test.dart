import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/transactions_ledger/domain/day_groups.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/presentation/transactions_ledger_screen.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 10);
  final older = today.subtract(const Duration(days: 5));

  test('FR-08-02: groupByDay, summarize and labels', () {
    final rows = [
      fakeTx(1, 50000, today, merchant: 'Swiggy'),
      fakeTx(2, 100000, today, type: TransactionType.credit),
      fakeTx(3, 9900, today, type: TransactionType.transfer),
      fakeTx(4, 20000, older),
    ];
    final groups = groupByDay(rows);
    expect(groups, hasLength(2));
    expect(groups.first.summary.spentMinor, 50000);
    expect(groups.first.summary.incomeMinor, 100000);
    expect(groups.first.summary.netMinor, 50000);
    expect(dayLabel(groups.first.day, now), 'Today');
    expect(
      dayLabel(today.subtract(const Duration(days: 1)), now),
      'Yesterday',
    );
    expect(
      dayLabel(DateTime(2026, 10, 21), DateTime(2026, 10, 30)),
      'Wed, 21 Oct 2026',
    );
  });

  for (final dark in [false, true]) {
    testWidgets('FR-08-02, FR-20-18: day cards and totals (dark=$dark)',
        (t) async {
      final repo = FakeTxRepo([
        fakeTx(1, 50000, today, merchant: 'Swiggy'),
        fakeTx(
          2,
          100000,
          today,
          type: TransactionType.credit,
          merchant: 'ACME',
        ),
        fakeTx(3, 20000, older, merchant: 'Uber'),
      ]);
      await pumpLedgerApp(
        t,
        txs: repo,
        dark: dark,
        home: const TransactionsLedgerScreen(
          filter: LedgerFilter(),
          periodLabel: 'This month',
        ),
        routes: [
          GoRoute(
            path: '/transaction/:id',
            builder: (_, s) => Text('detail ${s.pathParameters['id']}'),
          ),
        ],
      );
      await t.pump();
      expect(find.text('Today'), findsOneWidget);
      final olderLabel = dayLabel(
        DateTime(older.year, older.month, older.day),
        now,
      );
      expect(find.text(olderLabel), findsOneWidget);
      final income = t.widget<Text>(find.byKey(const Key('sum_income')));
      expect(income.data, '₹1,000');
      expect(t.widget<Text>(find.byKey(const Key('sum_spent'))).data, '₹700');
      expect(t.widget<Text>(find.byKey(const Key('sum_net'))).data, '₹300');
      expect(find.text('3 transactions · This month'), findsOneWidget);
      expect(find.text('-₹500.00'), findsOneWidget);
      expect(find.text('+₹1,000.00'), findsOneWidget);

      await t.tap(find.byKey(const Key('tx-1')));
      await t.pumpAndSettle();
      expect(find.text('detail 1'), findsOneWidget);
    });
  }

  testWidgets('FR-20-19: empty state by cause', (t) async {
    await pumpLedgerApp(
      t,
      txs: FakeTxRepo([]),
      home: const TransactionsLedgerScreen(
        filter: LedgerFilter(query: 'zzz'),
        periodLabel: 'This month',
      ),
    );
    await t.pump();
    expect(find.text('Nothing matches “zzz” in this month.'), findsOneWidget);
  });

  testWidgets('FR-08-01: review banner opens /review', (t) async {
    final flagged = fakeTx(5, 1000, today, needsReview: true);
    await pumpLedgerApp(
      t,
      txs: FakeTxRepo([], pairs: [ReviewPair(flagged, null)]),
      home: const TransactionsLedgerScreen(
        filter: LedgerFilter(),
        periodLabel: 'This month',
      ),
      routes: [GoRoute(path: '/review', builder: (_, __) => const Text('rv'))],
    );
    await t.pump();
    expect(find.text('1 need review'), findsOneWidget);
    await t.tap(find.byKey(const Key('review_banner')));
    await t.pumpAndSettle();
    expect(find.text('rv'), findsOneWidget);
  });
}

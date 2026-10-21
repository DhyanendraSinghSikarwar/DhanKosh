import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/dedup_review/presentation/dedup_review_screen.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';

import '../../support/fake_ledger.dart';

void main() {
  final at = DateTime(2026, 10, 20, 9, 30);
  ReviewPair pair(int id, {bool withTarget = true}) => ReviewPair(
        fakeTx(
          id,
          45000,
          at,
          merchant: 'Swiggy',
          needsReview: true,
          reviewReason: 'Possible duplicate',
        ),
        withTarget ? fakeTx(id + 100, 45000, at, merchant: 'Swiggy') : null,
      );

  testWidgets('FR-07-12: lists pairs; Merge and Keep separate', (t) async {
    final txs = FakeTxRepo([], pairs: [pair(1), pair(2)]);
    await pumpLedgerApp(t, txs: txs, home: const DedupReviewScreen());
    await t.pump();
    expect(find.text('Possible duplicate'), findsNWidgets(2));
    expect(find.text('₹450.00'), findsNWidgets(4));

    await t.tap(find.byKey(const Key('merge_1')));
    await t.pump();
    await t.pump();
    expect(txs.merged, [1]);
    expect(find.byKey(const Key('pair_1')), findsNothing);

    await t.tap(find.byKey(const Key('keep_2')));
    await t.pump();
    await t.pump();
    expect(txs.kept, [2]);
    expect(find.byKey(const Key('review_empty')), findsOneWidget);
  });

  testWidgets('FR-07-12: Merge disabled when the target is gone', (t) async {
    await pumpLedgerApp(
      t,
      txs: FakeTxRepo([], pairs: [pair(1, withTarget: false)]),
      home: const DedupReviewScreen(),
    );
    await t.pump();
    expect(find.text('Removed'), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('merge_1'))).onPressed,
      isNull,
    );
  });
}

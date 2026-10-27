import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/transactions_ledger/domain/transfer_pairing.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

void main() {
  final d = DateTime(2026, 10, 10, 12);
  const card = AccountKind.card;
  const bill = TransferPairing.cardBillNote;

  test('FR-10-18: card purchases are listed, not in the headline', () {
    final c = SpendCalc.totals([
      fakeTx(1, 50000, d, category: Category.food),
      fakeTx(2, 120000, d, category: Category.shopping, kind: card),
    ]);
    expect(c.spentMinor, 50000);
    expect(c.cardPurchasesMinor, 120000);
    expect(c.netMinor, -50000);
  });

  test('FR-10-19: paired payment counts once, on the bank leg', () {
    final leg = fakeTx(
      1,
      120000,
      d,
      type: TransactionType.transfer,
      category: Category.transfer,
      note: bill,
    );
    final rec = fakeTx(
      2,
      120000,
      d.add(const Duration(days: 1)),
      type: TransactionType.transfer,
      category: Category.transfer,
      kind: card,
    );
    final c = SpendCalc.totals([leg, rec]);
    expect(c.spentMinor, 120000);
    expect(c.cardPaymentsMinor, 120000);
  });

  test('FR-10-19: unpaired card record counts; a context leg pairs it', () {
    final rec = fakeTx(
      2,
      70000,
      d,
      type: TransactionType.transfer,
      category: Category.transfer,
      kind: card,
    );
    expect(SpendCalc.totals([rec]).spentMinor, 70000);
    final leg = fakeTx(
      1,
      70000,
      d.subtract(const Duration(days: 2)),
      type: TransactionType.transfer,
      category: Category.transfer,
      note: bill,
    );
    // Leg outside the rows only pairs: nothing is counted twice.
    expect(SpendCalc.totals([rec], context: [leg]).spentMinor, 0);
    // Different amount does not pair.
    final other = fakeTx(
      3,
      60000,
      d,
      type: TransactionType.transfer,
      category: Category.transfer,
      note: bill,
    );
    expect(SpendCalc.totals([rec, other]).spentMinor, 130000);
  });

  test('FR-10-20: card credits are never income; card refunds not netted', () {
    final c = SpendCalc.totals([
      fakeTx(1, 90000, d, type: TransactionType.credit, kind: card),
      fakeTx(
        2,
        10000,
        d,
        type: TransactionType.credit,
        category: Category.refund,
        kind: card,
      ),
      fakeTx(3, 500000, d, type: TransactionType.credit),
      fakeTx(
        4,
        20000,
        d,
        type: TransactionType.credit,
        category: Category.refund,
      ),
      fakeTx(5, 100000, d),
    ]);
    expect(c.incomeMinor, 500000);
    expect(c.cardRefundMinor, 10000);
    expect(c.refundMinor, 20000);
    expect(c.netSpentMinor, 80000);
  });

  test('own transfers and investments stay out of spend', () {
    final c = SpendCalc.totals([
      fakeTx(
        1,
        30000,
        d,
        type: TransactionType.transfer,
        category: Category.transfer,
        note: 'Self transfer between your accounts',
      ),
      fakeTx(2, 40000, d, type: TransactionType.investment),
      fakeTx(3, 5000, d, needsReview: true),
    ]);
    expect(c.spentMinor, 0);
    expect(c.investedMinor, 40000);
    expect(
      SpendCalc.outflow(
        [fakeTx(2, 40000, d, type: TransactionType.investment)],
      ),
      40000,
    );
  });
}

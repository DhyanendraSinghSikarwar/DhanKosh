// A bill that is already paid is not shown or notified as coming (FR-12-23,
// FR-21-32).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_detector.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_ledger.dart';

void main() {
  final today = DateTime.utc(2026, 11, 9);
  final created = DateTime.utc(2026, 9).millisecondsSinceEpoch;
  RecurringItem rent({int day = 10, bool yearly = false}) => RecurringItem(
        id: 1,
        name: 'Rent',
        amountMinor: 1500000,
        income: false,
        frequency:
            yearly ? RecurringFrequency.yearly : RecurringFrequency.monthly,
        dayOfMonth: day,
        month: yearly ? 11 : null,
        category: Category.rent,
        createdAt: created,
      );

  LedgerTx pay(
    DateTime at, {
    String merchant = 'Rent to Mr Rao',
    int amount = 1500000,
    Category category = Category.rent,
    TransactionType type = TransactionType.debit,
  }) =>
      fakeTx(1, amount, at, merchant: merchant, type: type, category: category);

  test('paid early: the next due date is shown, with the payment date', () {
    final m = RecurringDetector.withManual(
      const [],
      [rent()],
      today,
      txs: [pay(DateTime(2026, 11, 8))],
    ).single;
    expect(m.nextDue, DateTime.utc(2026, 12, 10));
    expect(m.lastPaid, DateTime.utc(2026, 11, 8));
  });

  test('not paid: still due this month', () {
    final m = RecurringDetector.withManual(const [], [rent()], today).single;
    expect(m.nextDue, DateTime.utc(2026, 11, 10));
    expect(m.lastPaid, isNull);
  });

  test('matches by amount and category when the name differs', () {
    final paid = RecurringDetector.paymentFor(
      rent(),
      DateTime.utc(2026, 11, 10),
      today,
      [pay(DateTime(2026, 11, 7), merchant: 'Landlord', amount: 1495000)],
    );
    expect(paid, DateTime.utc(2026, 11, 7));
  });

  test('ignores the wrong way, the wrong amount, old and review rows', () {
    final due = DateTime.utc(2026, 11, 10);
    bool paid(LedgerTx t) =>
        RecurringDetector.paymentFor(rent(), due, today, [t]) != null;
    expect(
      paid(pay(DateTime(2026, 11, 8), type: TransactionType.credit)),
      isFalse,
    );
    expect(
      paid(
        pay(
          DateTime(2026, 11, 8),
          merchant: 'Shop',
          amount: 900000,
          category: Category.shopping,
        ),
      ),
      isFalse,
    );
    expect(paid(pay(DateTime(2026, 10))), isFalse);
    expect(
      paid(
        fakeTx(
          1,
          1500000,
          DateTime(2026, 11, 8),
          merchant: 'Rent',
          needsReview: true,
        ),
      ),
      isFalse,
    );
  });

  test('a yearly item paid moves to next year', () {
    final m = RecurringDetector.withManual(
      const [],
      [rent(day: 12, yearly: true)],
      today,
      txs: [pay(DateTime(2026, 11, 5))],
    ).single;
    expect(m.nextDue, DateTime.utc(2027, 11, 12));
  });
}

// Price-change detection and alert (FR-12-21, FR-21-31).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/recurring_transactions/domain/price_change.dart';

import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';

import '../../support/fake_ledger.dart';

void main() {
  final today = DateTime.utc(2026, 11, 9);
  DateTime at(int month, int day) => DateTime(2026, month, day, 12);
  LedgerTx tx(int id, int amt, String m, DateTime d) =>
      fakeTx(id, amt, d, merchant: m);

  test('a stable price that moves is found once', () {
    final txs = [
      tx(1, 49900, 'Netflix', at(8, 5)),
      tx(2, 49900, 'Netflix', at(9, 5)),
      tx(3, 49900, 'Netflix', at(10, 5)),
      tx(4, 64900, 'Netflix', at(11, 5)),
    ];
    final c = PriceChanges.detect(txs, today).single;
    expect(
      [c.name, c.oldMinor, c.newMinor, c.txId],
      ['Netflix', 49900, 64900, 4],
    );
    final d = AlertRules.priceChangeAlerts(
      changes: [c],
      settings: const AlertSettings(),
      alerted: {},
    ).single;
    expect(d.title, 'Netflix now ₹649');
    expect(d.body, 'Was ₹499. Price went up.');
    expect(
      AlertRules.priceChangeAlerts(
        changes: [c],
        settings: const AlertSettings(),
        alerted: {d.key},
      ),
      isEmpty,
    );
  });

  test('varying purchases, tiny changes and old charges are ignored', () {
    final varying = [
      tx(1, 20000, 'Cafe', at(8, 5)),
      tx(2, 45000, 'Cafe', at(9, 5)),
      tx(3, 12000, 'Cafe', at(10, 5)),
      tx(4, 64900, 'Cafe', at(11, 5)),
    ];
    expect(PriceChanges.detect(varying, today), isEmpty);
    final tiny = [
      for (var i = 0; i < 3; i++) tx(i, 49900, 'Gym', at(8 + i, 5)),
      tx(9, 50100, 'Gym', at(11, 5)),
    ];
    expect(PriceChanges.detect(tiny, today), isEmpty);
    final old = [
      for (var i = 0; i < 3; i++) tx(i, 49900, 'Gym', at(6 + i, 5)),
      tx(9, 64900, 'Gym', at(9, 20)),
    ];
    expect(PriceChanges.detect(old, today), isEmpty);
  });
}

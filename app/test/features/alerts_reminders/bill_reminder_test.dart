// Bill reminders with Mark paid / Skip this time (FR-21-30).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_state_stores_impl.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_action_handler.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_text.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import 'alerts_engine_test.dart' show FakePoster;

class _Paid implements CardPaidStore {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  final today = DateTime.utc(2026, 11, 6);
  const settings = AlertSettings();

  BillReminderInput bill({int dueIn = 1, bool paid = false, int? acc = 3}) =>
      BillReminderInput(
        name: 'Rent',
        amountMinor: 1500000,
        nextDue: today.add(Duration(days: dueIn)),
        categoryName: 'rent',
        accountId: acc,
        paid: paid,
      );

  List<AlertDecision> run({
    List<BillReminderInput>? bills,
    int hour = 9,
    AlertSettings s = settings,
    Set<String> alerted = const {},
  }) =>
      AlertRules.billReminders(
        bills: bills ?? [bill()],
        today: today,
        hour: hour,
        settings: s,
        alerted: alerted,
      );

  test('due tomorrow: one reminder with Mark paid and Skip', () {
    final d = run().single;
    expect(d.title, 'Rent ₹15,000 due tomorrow');
    expect(d.actions.map((a) => a.id), ['billPaid', 'billSkip']);
    expect(d.key, 'billrem:Rent:2026-11-07');
    expect(run(bills: [bill(dueIn: 0)]).single.title, 'Rent ₹15,000 due today');
  });

  test('quiet when paid, too early, off, repeated, or not near', () {
    expect(run(bills: [bill(paid: true)]), isEmpty);
    expect(run(hour: 7), isEmpty);
    expect(run(s: const AlertSettings(billReminders: false)), isEmpty);
    expect(run(alerted: {'billrem:Rent:2026-11-07'}), isEmpty);
    expect(run(bills: [bill(dueIn: 2)]), isEmpty);
    expect(run(bills: [bill(dueIn: -1)]), isEmpty);
  });

  test('Mark paid books a manual payment; Skip books nothing', () async {
    final env = TestEnv();
    addTearDown(env.close);
    final poster = FakePoster();
    final h = AlertActionHandler(
      cardState: CardReminderStateStoreImpl(env.db),
      paid: _Paid(),
      txs: env.txs,
      poster: poster,
      nowMs: () => t0,
    );
    await env.ingest(parsed(amountMinor: 100, ref: 'seed'));
    final acc = (await env.accounts.watchVisible().first).single.id;
    final payload = run(bills: [bill(acc: acc)]).single.actions.first.payload;
    expect(await h.handle({'a': 'billPaid', ...payload}), isTrue);
    final rows = await env.db.select(env.db.transactions).get();
    expect(rows.where((r) => r.merchant == 'Rent'), hasLength(1));
    final rent = rows.firstWhere((r) => r.merchant == 'Rent');
    expect(rent.amountMinor, 1500000);

    expect(rent.type, 'DEBIT');
    expect(poster.cancelled, contains(AlertText.stableId(payload['key']!)));

    expect(await h.handle({'a': 'billSkip', ...payload}), isTrue);
    expect(await env.db.select(env.db.transactions).get(), hasLength(2));
    expect(await h.handle({'a': 'billPaid', 'name': 'x'}), isFalse);
    expect(Category.values.map((c) => c.name), contains('rent'));
  });
}

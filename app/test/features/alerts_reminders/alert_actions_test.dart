import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_state_stores_impl.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_action_handler.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/alerts_reminders/domain/alerts_engine.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/expense_tracking/data/budget_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/data/recurring_repository_impl.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import 'alerts_engine_test.dart' show FakePoster, FakeSettings;

class _Paid implements CardPaidStore {
  final marked = <String>[];
  @override
  Future<void> markPaid(int cardId, int dueEpochDay) async =>
      marked.add(CardPaidStore.key(cardId, dueEpochDay));
  @override
  Future<void> undoPaid(int cardId, int dueEpochDay) async {}
  @override
  Stream<Set<String>> watchPaid() => Stream.value({});
}

void main() {
  late TestEnv env;
  late FakePoster poster;

  setUp(() {
    env = TestEnv();
    poster = FakePoster();
  });
  tearDown(() => env.close());

  test('action routes carry the action name and payload (FR-21-03)', () {
    const paid = AlertAction(
      id: 'com.hisaab.app.CARD_DUE_PAID',
      label: 'Mark paid',
      payload: {'cardId': '3', 'dueEpochDay': '20000'},
    );
    final uri = Uri.parse(alertActionRoute(paid));
    expect(uri.path, '/alert-action');
    expect(uri.queryParameters['a'], 'paid');
    expect(uri.queryParameters['cardId'], '3');
  });

  test('mark paid and remind tomorrow update state (FR-21-10)', () async {
    final state = CardReminderStateStoreImpl(env.db);
    final paid = _Paid();
    final h = AlertActionHandler(
      cardState: state,
      paid: paid,
      txs: env.txs,
      poster: poster,
      nowMs: () => t0,
    );
    final today = epochDayOf(
      DateTime.fromMillisecondsSinceEpoch(t0 + 19800000, isUtc: true),
    );
    final due = today + 3;
    expect(
      await h.handle({'a': 'snooze', 'cardId': '3', 'dueEpochDay': '$due'}),
      isTrue,
    );
    final snoozed = await state.read(3, due);
    expect(snoozed?.snoozedUntilEpochDay, isNotNull);
    expect(poster.cancelled, [AlertRules.cardBillIdBase + 9]);
    await h.handle({'a': 'paid', 'cardId': '3', 'dueEpochDay': '$due'});
    expect((await state.read(3, due))?.paid, isTrue);
    expect(paid.marked, ['3|$due']);
    expect(await h.handle({'a': 'paid'}), isFalse);
    expect(await h.handle({'a': 'bogus'}), isFalse);
  });

  test('category button recategorises and confirms (FR-21-03)', () async {
    final r = await env.ingest(parsed());
    final id = r.transactionId!;
    final h = AlertActionHandler(
      cardState: CardReminderStateStoreImpl(env.db),
      paid: _Paid(),
      txs: env.txs,
      poster: poster,
      nowMs: () => t0,
    );
    expect(
      await h.handle({'a': 'category', 'txId': '$id', 'category': 'shopping'}),
      isTrue,
    );
    expect((await env.txs.byId(id))?.category, Category.shopping);
    expect(poster.posted.single.title, 'Saved as Shopping');
  });

  test('engine posts a card reminder once and a new-transaction alert',
      () async {
    final r = await env.ingest(parsed());
    final today =
        DateTime.fromMillisecondsSinceEpoch(t0 + 19800000, isUtc: true);
    final due = DateTime.utc(today.year, today.month, today.day + 2)
            .millisecondsSinceEpoch ~/
        86400000;
    final state = CardReminderStateStoreImpl(env.db);
    final engine = AlertsEngine(
      budgets: BudgetRepositoryImpl(env.db),
      recurring: RecurringRepositoryImpl(env.db),
      accounts: env.accounts,
      alerted: AlertedKeyStoreImpl(env.db),
      poster: poster,
      settings: FakeSettings(),
      txs: env.txs,
      cardState: state,
      cards: () async => [
        CardLimit(
          id: 3,
          name: 'Test Card',
          bankName: 'Test Bank',
          last4: '1234',
          paid: false,
          position: CardPosition(billedMinor: 500000, dueDay: due),
        ),
      ],
      nowMs: () => t0,
    );
    expect(await engine.run(), 2);
    final card = poster.posted.firstWhere((d) => d.kind == AlertKind.cardBill);
    expect(card.title, 'Test Card bill due in 2 days');
    expect(card.actions.map((a) => a.label), ['Mark paid', 'Remind tomorrow']);
    final tx = poster.posted.firstWhere(
      (d) => d.kind == AlertKind.newTransaction,
    );
    expect(
      tx.notificationId,
      AlertRules.newTransactionIdBase + r.transactionId!,
    );
    expect(tx.actions, isNotEmpty);
    expect(await engine.run(), 0);
  });
}

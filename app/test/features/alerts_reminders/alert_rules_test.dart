import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_text.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:parser_core/parser_core.dart';

int r(int rupees) => rupees * 100;

void main() {
  const s90 = AlertSettings();
  final today = DateTime.utc(2026, 10, 17);

  group('budget thresholds (FR-21-05, TC-21)', () {
    final food = Budget(category: Category.food, monthlyLimitMinor: r(10000));

    List<AlertDecision> run(
      int used, {
      Set<String> alerted = const {},
      AlertSettings s = s90,
      Budget? b,
    }) =>
        AlertRules.budgetAlerts(
          budgets: [b ?? food],
          spentByCategory: {Category.food: used},
          year: 2026,
          month: 10,
          settings: s,
          alerted: alerted,
        );

    test('below the user percent: nothing', () {
      expect(run(r(8999)), isEmpty);
      expect(run(0), isEmpty);
    });

    test('exactly at 90% fires the 90 level; one paisa less does not', () {
      final d = run(r(9000)).single;
      expect(d.key, 'budget:FOOD:2026-10:90');
      expect(d.title, 'Food & Dining: 90% of budget used');
      expect(d.body, '₹9,000 of ₹10,000 spent. ₹1,000 left for October 2026.');
      expect(d.link, 'hisaab://budgets');
      expect(d.channel, AlertChannel.budgetsBills);
      expect(run(r(9000) - 1), isEmpty);
    });

    test('already alerted at 90 stays silent until 100 is reached', () {
      final a = {'budget:FOOD:2026-10:90'};
      expect(run(r(9500), alerted: a), isEmpty);
      expect(run(r(9999), alerted: a), isEmpty);
      final d = run(r(10000), alerted: a).single;
      expect(d.key, 'budget:FOOD:2026-10:100');
      expect(d.title, 'Food & Dining: budget used up');
      expect(d.body, '₹10,000 spent against ₹10,000, ₹0 over.');
    });

    test('worked example: 10,200 against 10,000 is 200 over, then silent', () {
      final d = run(r(10200)).single;
      expect(d.key.endsWith(':100'), isTrue);
      expect(d.body, '₹10,200 spent against ₹10,000, ₹200 over.');
      expect(run(r(10200), alerted: {d.key}), isEmpty);
    });

    test('only the highest reached level is sent', () {
      expect(run(r(12000)).length, 1);
      expect(run(r(12000)).single.key.endsWith(':100'), isTrue);
    });

    test('user percent 80 and 95; percent 100 collapses the levels', () {
      expect(
        run(r(8000), s: const AlertSettings(budgetAlertPercent: 80)).length,
        1,
      );
      expect(
        run(r(9400), s: const AlertSettings(budgetAlertPercent: 95)),
        isEmpty,
      );
      expect(
        run(r(9500), s: const AlertSettings(budgetAlertPercent: 95)).length,
        1,
      );
      final d =
          run(r(10000), s: const AlertSettings(budgetAlertPercent: 100)).single;
      expect(d.key.endsWith(':100'), isTrue);
    });

    test('zero-limit budget never alerts; different month is a new key', () {
      expect(
        run(
          r(100),
          b: const Budget(category: Category.food, monthlyLimitMinor: 0),
        ),
        isEmpty,
      );
      final other = AlertRules.budgetAlerts(
        budgets: [food],
        spentByCategory: {Category.food: r(9500)},
        year: 2026,
        month: 11,
        settings: s90,
        alerted: {'budget:FOOD:2026-10:90'},
      );
      expect(other.single.key, 'budget:FOOD:2026-11:90');
    });

    test('stable id is deterministic and in range', () {
      final a = AlertText.stableId('budget:FOOD:2026-10:90');
      expect(a, AlertText.stableId('budget:FOOD:2026-10:90'));
      expect(a, isNot(AlertText.stableId('budget:FOOD:2026-10:100')));
      expect(a, inInclusiveRange(1000000, 2000999999));
    });
  });

  group('low balance bills (FR-21-06)', () {
    BillDueInput bill({
      int days = 2,
      int amount = 649,
      int? balance = 300,
      bool bank = true,
      String? label = 'HDFC Bank',
    }) =>
        BillDueInput(
          name: 'Netflix',
          amountMinor: r(amount),
          nextDue: today.add(Duration(days: days)),
          accountLabel: label,
          accountLast4: '1234',
          accountBalanceMinor: balance == null ? null : r(balance),
          accountIsBank: bank,
        );

    List<AlertDecision> run(
      List<BillDueInput> b, {
      Set<String> alerted = const {},
    }) =>
        AlertRules.lowBalanceBillAlerts(
          bills: b,
          today: today,
          alerted: alerted,
        );

    test('worked example: Netflix 649 in 2 days, balance 300', () {
      final d = run([bill()]).single;
      expect(d.title, 'Netflix ₹649 due in 2 days');
      expect(
        d.body,
        "HDFC Bank ••1234 has ₹300. Add ₹349 so it doesn't bounce.",
      );
      expect(d.key, 'bill:Netflix:2026-10-19');
      expect(d.link, 'hisaab://bills');
    });

    test('titles for today and tomorrow; window is 0..3 days', () {
      expect(run([bill(days: 0)]).single.title, 'Netflix ₹649 due today');
      expect(run([bill(days: 1)]).single.title, 'Netflix ₹649 due tomorrow');
      expect(run([bill(days: 3)]).length, 1);
      expect(run([bill(days: 4)]), isEmpty);
      expect(run([bill(days: -1)]), isEmpty);
    });

    test(
        'balance equal to the amount is enough; unknown balance, card or no account are skipped',
        () {
      expect(run([bill(balance: 649)]), isEmpty);
      expect(run([bill(balance: 648)]).length, 1);
      expect(run([bill(balance: null)]), isEmpty);
      expect(run([bill(bank: false)]), isEmpty);
      expect(run([bill(label: null)]), isEmpty);
    });

    test('once per (name, due date)', () {
      expect(run([bill()], alerted: {'bill:Netflix:2026-10-19'}), isEmpty);
    });
  });

  group('insurance renewals (FR-21-07)', () {
    RenewalInput pol(int days) => RenewalInput(
          insurer: 'HDFC Ergo',
          kindLabel: 'Health',
          premiumMinor: r(18500),
          lastPaid: DateTime.utc(2025, 10, 17 + days),
          nextDue: today.add(Duration(days: days)),
        );
    List<AlertDecision> run(int days, {Set<String> alerted = const {}}) =>
        AlertRules.renewalAlerts(
          policies: [pol(days)],
          today: today,
          alerted: alerted,
        );

    test('0..7 day window and wording', () {
      expect(run(0).single.title, 'Health insurance renews today');
      expect(run(1).single.title, 'Health insurance renews in 1 day');
      expect(run(7).single.title, 'Health insurance renews in 7 days');
      expect(run(8), isEmpty);
      expect(run(-1), isEmpty);
      final d = run(5).single;
      expect(
        d.body,
        'HDFC Ergo: last premium ₹18,500 on 2025-10-22. Renew in time to stay covered.',
      );
      expect(d.key, 'renewal:HDFC Ergo:2026-10-22');
    });

    test('once per (insurer, due date)', () {
      expect(run(5, alerted: {'renewal:HDFC Ergo:2026-10-22'}), isEmpty);
    });
  });

  group('untracked changes (FR-21-08)', () {
    final now = DateTime.utc(2026, 10, 17).millisecondsSinceEpoch;
    GapInput gap(
      String k, {
      bool card = false,
      bool left = true,
      int ageDays = 1,
      int delta = -250000,
    }) =>
        GapInput(
          key: k,
          accountId: 5,
          accountLabel: 'HDFC ••1234',
          deltaMinor: delta,
          card: card,
          moneyLeft: left,
          toTimeMs: now - ageDays * 86400000,
        );

    test('four text variants', () {
      List<String> bodies(GapInput g) =>
          AlertRules.gapAlerts(gaps: [g], nowMs: now, settings: s90)
              .map((e) => e.body)
              .toList();
      expect(
        bodies(gap('a', card: true)),
        ['HDFC ••1234: ₹2,500 of limit used with no message. Add it?'],
      );
      expect(
        bodies(gap('a', card: true, left: false)),
        ['HDFC ••1234: ₹2,500 of limit freed with no message. Add it?'],
      );
      expect(
        bodies(gap('a')),
        ['HDFC ••1234: ₹2,500 left the account with no message. Add it?'],
      );
      expect(
        bodies(gap('a', left: false)),
        ['HDFC ••1234: ₹2,500 came in with no message. Add it?'],
      );
    });

    test('14-day window boundary, max 3 per run, once each, setting gate', () {
      List<AlertDecision> run(
        List<GapInput> g, {
        Set<String> alerted = const {},
        AlertSettings s = s90,
      }) =>
          AlertRules.gapAlerts(
            gaps: g,
            nowMs: now,
            settings: s,
            alerted: alerted,
          );
      expect(run([gap('a', ageDays: 14)]).length, 1);
      expect(run([gap('a', ageDays: 15)]), isEmpty);
      final five = [for (var i = 0; i < 5; i++) gap('g$i')];
      expect(run(five).length, 3);
      expect(
        run(five, alerted: {'gap:g0'}).map((e) => e.key),
        ['gap:g1', 'gap:g2', 'gap:g3'],
      );
      expect(
        run(five, s: const AlertSettings(transactionNotifications: false)),
        isEmpty,
      );
      final d = run([gap('x')]).single;
      expect(d.title, 'Untracked change');
      expect(d.link, 'hisaab://account/5');
    });
  });

  group('card bill reminders (FR-21-09, FR-21-10)', () {
    final todayDay = epochDayOf(today);
    CardBillInput card({
      int days = 5,
      int? billed = 1234500,
      int? min,
      bool estimated = false,
      bool paid = false,
      Set<DueStage> sent = const {},
      int? snooze,
      int id = 4,
    }) =>
        CardBillInput(
          cardId: id,
          name: 'HDFC Regalia',
          billedMinor: billed,
          dueEpochDay: todayDay + days,
          minDueMinor: min,
          estimated: estimated,
          paid: paid,
          sent: sent,
          snoozedUntilEpochDay: snooze,
        );
    List<AlertDecision> run(CardBillInput c, {AlertSettings s = s90}) =>
        AlertRules.cardBillAlerts(
          cards: [c],
          todayEpochDay: todayDay,
          settings: s,
        );

    test('stage table: days -> stage', () {
      DueStage? stage(int days) {
        final d = run(card(days: days));
        return d.isEmpty ? null : d.single.stage;
      }

      expect(stage(10), isNull);
      expect(stage(6), isNull);
      expect(stage(5), DueStage.days5);
      expect(stage(3), DueStage.days5);
      expect(stage(2), DueStage.days2);
      expect(stage(1), DueStage.days2);
      expect(stage(0), DueStage.dueDay);
      expect(stage(-1), DueStage.overdue);
      expect(stage(-7), DueStage.overdue);
      expect(stage(-8), isNull);
    });

    test('titles, body, id, actions and deep link', () {
      final d = run(card(min: 61725)).single;
      expect(d.title, 'HDFC Regalia bill due in 5 days');
      expect(d.body, '₹12,345 · pay by 22 Oct. Minimum ₹617.');
      expect(d.notificationId, 30000 + 4 * 3);
      expect(d.channel, AlertChannel.budgetsBills);
      expect(d.link, 'hisaab://account/4');
      expect(d.actions.map((a) => a.label), ['Mark paid', 'Remind tomorrow']);
      expect(d.actions.first.id, 'com.hisaab.app.CARD_DUE_PAID');
      expect(run(card(days: 1)).single.title, 'HDFC Regalia bill due tomorrow');
      expect(run(card(days: 0)).single.title, 'HDFC Regalia bill due today');
      expect(run(card(days: -2)).single.title, 'HDFC Regalia bill overdue');
      expect(
        run(card(estimated: true)).single.body,
        'About ₹12,345 · pay by 22 Oct.',
      );
    });

    test('sent stage, paid and snoozed suppress; paid cancels', () {
      expect(run(card(sent: {DueStage.days5})), isEmpty);
      expect(
        run(card(days: 1, sent: {DueStage.days5, DueStage.days2})),
        isEmpty,
      );
      expect(
        run(card(days: 1, sent: {DueStage.days5})).single.stage,
        DueStage.days2,
      );
      final paid = run(card(paid: true)).single;
      expect(paid.cancel, isTrue);
      expect(paid.notificationId, 30012);
      expect(run(card(snooze: todayDay + 1)), isEmpty);
      expect(run(card(snooze: todayDay)).length, 1); // snooze ends today
    });

    test('not billed or no due day cancels; reminders off sends nothing', () {
      expect(run(card(billed: 0)).single.cancel, isTrue);
      expect(run(card(billed: null)).single.cancel, isTrue);
      expect(
        run(const CardBillInput(cardId: 4, name: 'X', billedMinor: 100))
            .single
            .cancel,
        isTrue,
      );
      expect(
        run(card(), s: const AlertSettings(cardDueReminders: false)),
        isEmpty,
      );
    });
  });

  group('new transaction and other texts (FR-21-02..04, FR-21-12)', () {
    AlertDecision? tx({
      bool inserted = true,
      bool transfer = false,
      bool credit = false,
      int amount = 25000,
      String cur = 'INR',
      Category cat = Category.food,
      List<Category> used = const [
        Category.shopping,
        Category.food,
        Category.transport,
        Category.other,
      ],
      AlertSettings s = s90,
    }) =>
        AlertRules.newTransactionAlert(
          txId: 77,
          amountMinor: amount,
          currency: cur,
          isCredit: credit,
          who: 'Swiggy',
          category: cat,
          inserted: inserted,
          isTransfer: transfer,
          settings: s,
          last4: '1234',
          usedMostFirst: used,
        );

    test('title, text, id, link and buttons (worked example)', () {
      final d = tx()!;
      expect(d.title, '₹250 at Swiggy');
      expect(d.body, 'Food & Dining · ••1234 · expand to change');
      expect(d.notificationId, 10077);
      expect(d.link, 'hisaab://transaction/77');
      expect(d.channel, AlertChannel.newTransactions);
      expect(
        d.actions.map((a) => a.label),
        ['Shopping', 'Transport', 'Groceries'],
      );
      expect(d.actions.first.payload, {'txId': '77', 'category': 'shopping'});
    });

    test('credit title, paise shown when non-zero, foreign symbol kept', () {
      expect(
        tx(credit: true, amount: 123450)!.title,
        '₹1,234.50 received from Swiggy',
      );
      expect(tx(cur: 'USD', amount: 1000)!.title, r'$10 at Swiggy');
    });

    test('not sent for duplicates, transfers or when the switch is off', () {
      expect(tx(inserted: false), isNull);
      expect(tx(transfer: true), isNull);
      expect(
        tx(s: const AlertSettings(transactionNotifications: false)),
        isNull,
      );
    });

    test('alternative categories: credit defaults, exclusions, cap of 3', () {
      expect(
        AlertRules.alternativeCategories(
          current: Category.salary,
          isCredit: true,
          usedMostFirst: const [],
        ),
        [Category.refund, Category.income, Category.transfer],
      );
      expect(
        AlertRules.alternativeCategories(
          current: Category.food,
          isCredit: false,
          usedMostFirst: const [
            Category.other,
            Category.food,
            Category.food,
          ],
        ),
        [Category.groceries, Category.shopping, Category.transport],
      );
    });

    test('saved confirmation times out in 4 s', () {
      final d =
          AlertRules.categorySavedAlert(txId: 77, category: Category.shopping);
      expect(d.title, 'Saved as Shopping');
      expect(d.timeoutMs, 4000);
      expect(d.notificationId, 10077);
    });

    test('balance updated: single, several and gating', () {
      const one = BalanceGapInput(
        key: 'a',
        label: 'HDFC ••1234',
        unexplainedMinor: -500000,
      );
      final single =
          AlertRules.balanceUpdatedAlert(gaps: [one], settings: s90)!;
      expect(single.notificationId, 9000);
      expect(single.title, 'HDFC ••1234 updated');
      expect(single.body, '₹5,000 not explained · transactions may be missing');
      const two =
          BalanceGapInput(key: 'b', label: 'SBI ••9', unexplainedMinor: 120000);
      final multi =
          AlertRules.balanceUpdatedAlert(gaps: [one, two], settings: s90)!;
      expect(multi.title, '2 balances updated');
      expect(
        multi.body,
        'HDFC ••1234 · ₹5,000 not explained · SBI ••9 · ₹1,200 not explained',
      );
      expect(
        AlertRules.balanceUpdatedAlert(gaps: const [], settings: s90),
        isNull,
      );
      expect(
        AlertRules.balanceUpdatedAlert(
          gaps: [one],
          settings: const AlertSettings(transactionNotifications: false),
        ),
        isNull,
      );
    });

    test('statement locked shows no figures', () {
      final d =
          AlertRules.statementLockedAlert(statementId: 9, bank: 'HDFC Bank');
      expect(d.title, 'HDFC Bank statement detected');
      expect(d.notificationId, 4009);
      expect(d.link, 'hisaab://statements?unlock=9');
      expect(d.channel, AlertChannel.statements);
      expect(
        AlertRules.statementLockedAlert(statementId: 1).title,
        'A statement detected',
      );
    });

    test('money text: en-IN grouping', () {
      expect(AlertText.money(r(123456)), '₹1,23,456');
      expect(AlertText.money(99), '₹0');
      expect(AlertText.money(99, showPaise: true), '₹0.99');
      expect(AlertText.money(-r(1500)), '-₹1,500');
      expect(AlertText.money(r(12345678)), '₹1,23,45,678');
      expect(AlertText.monthYear(2026, 10), 'October 2026');
    });
  });
}

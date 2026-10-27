import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_state_stores_impl.dart';
import 'package:hisaab/features/alerts_reminders/domain/alerted_key_store.dart';
import 'package:hisaab/features/alerts_reminders/domain/card_reminder_state_store.dart';
import 'package:hisaab/features/expense_tracking/data/budget_repository_impl.dart';
import 'package:hisaab/features/income_tracking/data/income_repository_impl.dart';
import 'package:hisaab/features/loans/data/loan_link_repository_impl.dart';
import 'package:hisaab/features/loans/domain/loan_link_repository.dart';
import 'package:hisaab/features/recurring_transactions/data/recurring_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('budgets (FR-10-09, FR-10-11)', () {
    test('save, replace, delete, reject excluded', () async {
      final r = BudgetRepositoryImpl(env.db);
      await r.save(Category.food, 1000000);
      await r.save(Category.food, 2000000);
      await r.save(Category.emiLoan, 5000);
      var all = await r.all();
      expect(all, hasLength(2));
      expect(
        all.firstWhere((b) => b.category == Category.food).monthlyLimitMinor,
        2000000,
      );
      expect(() => r.save(Category.salary, 1), throwsArgumentError);
      expect(() => r.save(Category.food, 0), throwsArgumentError);
      await r.delete(Category.food);
      all = await r.all();
      expect(all.single.category, Category.emiLoan);
      expect((await r.watchAll().first).length, 1);
    });

    test('category totals: DEBIT + INVESTMENT, priced only, no review filter',
        () async {
      final r = BudgetRepositoryImpl(env.db);
      await env.ingest(parsed(amountMinor: 10000, ref: 'a'));
      await env.ingest(parsed(amountMinor: 5000, ref: 'b', merchant: 'Zomato'));
      await env.ingest(
        parsed(
          amountMinor: 7000,
          ref: 'c',
          merchant: 'Zerodha',
          type: TransactionType.investment,
          category: Category.investment,
        ),
      );
      await env.ingest(
        parsed(
          amountMinor: 90000,
          ref: 'd',
          type: TransactionType.credit,
          category: Category.salary,
          merchant: 'ACME',
        ),
      );
      await env.ingest(
        parsed(amountMinor: 100, ref: 'e', currency: 'USD', merchant: 'Shop'),
      );
      final t = await r.categoryTotals(t0 - hour, t0 + hour);
      expect(t[Category.food], 15000);
      expect(t[Category.investment], 7000);
      expect(t.containsKey(Category.salary), isFalse);
      expect(await r.categoryTotals(0, 1), isEmpty);
    });
  });

  group('income (FR-11-05, FR-11-06)', () {
    test('income, cash flow and monthly flows exclude transfer and review',
        () async {
      final r = IncomeRepositoryImpl(env.txs);
      await env.ingest(
        parsed(
          amountMinor: 6000000,
          ref: 's',
          type: TransactionType.credit,
          category: Category.salary,
          merchant: 'ACME',
        ),
      );
      await env.ingest(
        parsed(
          amountMinor: 500,
          ref: 't',
          type: TransactionType.credit,
          category: Category.transfer,
          merchant: 'Self',
        ),
      );
      await env.ingest(parsed(amountMinor: 3500000, ref: 'x'));
      await env.ingest(
        parsed(
          amountMinor: 1000000,
          ref: 'i',
          merchant: 'MF',
          type: TransactionType.investment,
          category: Category.investment,
        ),
      );
      const from = t0 - 5 * 86400000;
      const to = t0 + 5 * 86400000;
      expect(await r.incomeBetween(from, to), 6000000);
      final f = await r.cashFlow(from, to);
      expect(f.savedMinor, 1500000);
      expect(f.ratePercent, 25);
      final m = await r.monthlyFlows(from, to);
      expect(m.single.yearMonth, '2026-09');
      expect(m.single.spentMinor, 3500000);
      expect(await r.incomeBetween(0, 1), 0);
    });
  });

  group('recurring items (FR-12-03)', () {
    test('add, update, delete, validate, count by account', () async {
      final r = RecurringRepositoryImpl(env.db, now: () => 5);
      const d = RecurringDraft(
        name: ' Rent ',
        amountMinor: 2500000,
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 14,
        category: Category.rent,
        accountId: 7,
        month: 3,
      );
      final id = await r.add(d);
      var item = (await r.all()).single;
      expect(item.name, 'Rent');
      expect(item.month, isNull);
      expect(item.createdAt, 5);
      expect(item.category, Category.rent);
      expect(await r.countForAccount(7), 1);
      await r.update(
        id,
        const RecurringDraft(
          name: 'Policy',
          amountMinor: 1,
          frequency: RecurringFrequency.yearly,
          dayOfMonth: 5,
          month: 3,
          category: Category.insurance,
          income: true,
        ),
      );
      item = (await r.watchAll().first).single;
      expect(item.frequency, RecurringFrequency.yearly);
      expect(item.month, 3);
      expect(item.income, isTrue);
      expect(await r.countForAccount(7), 0);
      expect(
        () => r.add(
          const RecurringDraft(
            name: '',
            amountMinor: 1,
            frequency: RecurringFrequency.monthly,
            dayOfMonth: 1,
            category: Category.food,
          ),
        ),
        throwsArgumentError,
      );
      await r.delete(id);
      expect(await r.all(), isEmpty);
    });
  });

  group('loan links (FR-15-10, FR-15-11)', () {
    test('link, unlink, dismiss, clear', () async {
      final r = LoanLinkRepositoryImpl(env.db);
      await r.linkTx(10, 1);
      await r.linkPayee('propelld', 1);
      await r.linkPayee('bajaj', 2);
      await r.dismissPayee('gym');
      var s = await r.read();
      expect(s.tx, {10: 1});
      expect(s.payee, {'propelld': 1, 'bajaj': 2});
      expect(s.manualPayees, {'propelld', 'bajaj'});
      expect(s.dismissed, {'gym'});
      await r.clearLoan(1);
      await r.unlinkPayee('bajaj');
      await r.undismissPayee('gym');
      s = await r.read();
      expect(s.tx, isEmpty);
      expect(s.payee, isEmpty);
      expect(s.manualPayees, {'propelld'});
      expect(s.dismissed, isEmpty);
      expect(LoanLinkSet.keyOf(' Propelld ', null), 'propelld');
      expect(LoanLinkSet.keyOf(null, 'A@b'), 'a@b');
    });
  });

  group('alert state (FR-21-04, FR-21-11, FR-21-14)', () {
    test('alerted keys capped at newest 300', () async {
      final s = AlertedKeyStoreImpl(env.db);
      for (var i = 0; i < 305; i++) {
        await s.add('k$i', i);
      }
      final all = await s.all();
      expect(all, hasLength(AlertedKeyStore.cap));
      expect(all.contains('k0'), isFalse);
      expect(all.contains('k304'), isTrue);
      expect(await s.has('k304'), isTrue);
      await s.add('k304', 999);
      expect((await s.all()).length, 300);
      await s.clear();
      expect(await s.all(), isEmpty);
    });

    test('card reminder state: stages, paid, snooze, prune after 120 days',
        () async {
      final s = CardReminderStateStoreImpl(env.db);
      expect(await s.read(1, 100), isNull);
      await s.markSent(1, 100, 'days5', todayEpochDay: 95);
      await s.markSent(1, 100, 'days2', todayEpochDay: 98);
      await s.snooze(1, 100, 101, todayEpochDay: 98);
      var r = (await s.read(1, 100))!;
      expect(r.stagesSent, {'days5', 'days2'});
      expect(r.snoozedUntilEpochDay, 101);
      expect(r.paid, isFalse);
      await s.markPaid(1, 100, todayEpochDay: 99);
      r = (await s.read(1, 100))!;
      expect(r.paid, isTrue);
      expect(r.stagesSent, hasLength(2));
      await s.save(
        const CardReminderRecord(cardId: 2, dueEpochDay: 300),
        todayEpochDay: 300,
      );
      expect(await s.read(1, 100), isNull);
      expect(await s.read(2, 300), isNotNull);
    });

    test('balance notice once per IST day per account', () async {
      final s = BalanceNoticeStoreImpl(env.db);
      expect(await s.shouldNotify('a', 10), isTrue);
      await s.record('a', 10);
      expect(await s.shouldNotify('a', 10), isFalse);
      expect(await s.shouldNotify('a', 11), isTrue);
      expect(await s.shouldNotify('b', 10), isTrue);
      expect(await s.lastDay('a'), 10);
    });
  });
}

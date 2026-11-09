// Groups (F-39), split with people (F-40) and category split (F-41).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/expense_tracking/data/budget_repository_impl.dart';
import 'package:hisaab/features/people_split/data/people_repository_impl.dart';
import 'package:hisaab/features/people_split/domain/people.dart';
import 'package:hisaab/features/transaction_groups/data/tx_group_repository_impl.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_views.dart';
import 'package:hisaab/features/transactions_ledger/domain/tx_part.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('groups', () {
    test('totals, filter, membership and delete keep the transactions',
        () async {
      final repo = TxGroupRepositoryImpl(env.db);
      final a = await env.ingest(parsed(amountMinor: 30000, ref: 'a'));
      final b = await env.ingest(
        parsed(
          amountMinor: 50000,
          ref: 'b',
          time: t0 + hour,
          type: TransactionType.credit,
        ),
      );
      await env
          .ingest(parsed(amountMinor: 70000, ref: 'c', time: t0 + 2 * hour));
      final g = await repo.create(' Goa ');
      await repo.add(g, [a.transactionId!, b.transactionId!]);
      await repo.add(g, [a.transactionId!]); // twice is once

      final one = (await repo.watchAll().first).single;
      expect(
        [one.name, one.count, one.spentMinor, one.incomeMinor],
        ['Goa', 2, 30000, 50000],
      );
      final inGroup = await env.txs.watch(LedgerFilter(groupId: g)).first;
      expect(
        inGroup.map((t) => t.id).toSet(),
        {a.transactionId, b.transactionId},
      );

      await repo.setGroupsOf(a.transactionId!, {});
      expect((await repo.watchAll().first).single.count, 1);
      await repo.delete(g);
      expect(await repo.watchAll().first, isEmpty);
      expect(await env.db.select(env.db.transactions).get(), hasLength(3));
      expect(() => repo.create('  '), throwsArgumentError);
    });
  });

  group('people', () {
    test('equal shares leave the paise with you', () {
      expect(SplitMath.equalShares(10000, 3), [2500, 2500, 2500]);
      expect(SplitMath.equalShares(10000, 2), [3333, 3333]);
      expect(SplitMath.yourPart(10000, [3333, 3333]), 3334);
      expect(SplitMath.equalShares(0, 2), isEmpty);
      expect(SplitMath.yourPart(1000, [600, 600]), -200);
    });

    test('a split books what each person owes; repayments settle it', () async {
      final repo = PeopleRepositoryImpl(env.db);
      final tx = await env.ingest(parsed(amountMinor: 90000, ref: 'dinner'));
      final asha = await repo.addPerson(' Asha ');
      expect(await repo.addPerson('asha'), asha);
      final ravi = await repo.addPerson('Ravi');

      await repo.split(
        transactionId: tx.transactionId!,
        label: 'Split: Dinner',
        shares: {asha: 30000, ravi: 30000},
      );
      var people = await repo.all();
      expect(
        people.map((p) => (p.name, p.balanceMinor)),
        [('Asha', 30000), ('Ravi', 30000)],
      );
      expect(
        await repo.sharesOf(tx.transactionId!),
        {asha: 30000, ravi: 30000},
      );

      // Splitting again replaces the earlier shares.
      await repo.split(
        transactionId: tx.transactionId!,
        label: 'Split: Dinner',
        shares: {asha: 45000},
      );
      expect((await repo.all()).map((p) => p.balanceMinor), [45000, 0]);

      await repo.addEntry(asha, -45000, note: 'paid back');
      expect((await repo.all()).first.balanceMinor, 0);
      await repo.addEntry(ravi, 0); // ignored
      expect((await repo.all()).last.entryCount, 0);

      await repo.deletePerson(asha);
      people = await repo.all();
      expect(people.map((p) => p.name), ['Ravi']);
    });
  });

  group('category split', () {
    test('validation', () {
      expect(
        TxPart.validate(1000, [const TxPart(Category.food, 1000)]),
        isNotNull,
      );
      expect(
        TxPart.validate(
          1000,
          [const TxPart(Category.food, 600), const TxPart(Category.food, 400)],
        ),
        'Use each category once',
      );
      expect(
        TxPart.validate(
          1000,
          [const TxPart(Category.food, 600), const TxPart(Category.bills, 300)],
        ),
        'Parts must add up to the total',
      );
      expect(
        TxPart.validate(
          1000,
          [const TxPart(Category.food, 600), const TxPart(Category.bills, 400)],
        ),
        isNull,
      );
    });

    test('parts count in their categories, in lists and budgets', () async {
      final tx = await env.ingest(
        parsed(amountMinor: 200000, ref: 'shop', category: Category.shopping),
      );
      final id = tx.transactionId!;
      expect(
        () => env.txs.setParts(id, [const TxPart(Category.food, 1)]),
        throwsArgumentError,
      );
      await env.txs.setParts(id, [
        const TxPart(Category.food, 120000),
        const TxPart(Category.bills, 80000),
      ]);
      final row = (await env.txs.byId(id))!;
      expect(row.parts, hasLength(2));
      final groups = groupByCategory([row]);
      expect(
        {for (final g in groups) g.category: g.totalMinor},
        {Category.food: 120000, Category.bills: 80000},
      );

      final totals = await BudgetRepositoryImpl(env.db)
          .categoryTotals(t0 - 10 * 24 * hour, t0 + 10 * 24 * hour);
      expect(totals[Category.food], 120000);
      expect(totals[Category.bills], 80000);
      expect(totals.containsKey(Category.shopping), isFalse);

      await env.txs.setParts(id, const []);
      expect((await env.txs.byId(id))!.parts, isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  // FR-07-07, FR-08-17
  test('ingest inserts a row, its source and the account', () async {
    final r = await env.ingest(parsed(), raw: 'Rs 250 debited');
    expect(r.outcome, IngestOutcome.inserted);
    final tx = (await env.txs.byId(r.transactionId!))!;
    expect(tx.amountMinor, 25000);
    expect(tx.inrMinor, 25000);
    expect(tx.type, TransactionType.debit);
    expect(tx.category, Category.food);
    expect(tx.accountId, isNotNull);
    final srcs = await env.txs.sourcesOf(tx.id);
    expect(srcs.single.rawText, 'Rs 250 debited');
    expect(srcs.single.source, Source.sms);
    expect(await env.count('accounts'), 1);
  });

  // FR-07-02
  test('dedup by reference merges SMS and email into one row', () async {
    final a = await env.ingest(parsed(last4: null));
    final b = await env.ingest(
      parsed(source: Source.email, time: t0 + 5 * hour),
    );
    expect(b.outcome, IngestOutcome.merged);
    expect(b.transactionId, a.transactionId);
    expect(await env.count('transactions'), 1);
    expect(await env.count('transaction_sources'), 2);
    // The merge filled the account digits.
    expect((await env.txs.byId(a.transactionId!))!.accountLast4, '1234');
  });

  // FR-07-03
  test('dedup by hash merges within 30 minutes', () async {
    await env.ingest(parsed(ref: null));
    final b = await env.ingest(
      parsed(ref: null, source: Source.email, time: t0 + 2 * minute),
    );
    expect(b.outcome, IngestOutcome.merged);
    expect(await env.count('transactions'), 1);
  });

  // FR-07-03/04, FR-07-08: time window, missing reference, hours apart.
  test('same hash hours apart without a reference is flagged', () async {
    final a = await env.ingest(parsed(ref: null));
    final b = await env.ingest(
      parsed(ref: null, source: Source.email, time: t0 + 2 * hour),
    );
    expect(b.outcome, IngestOutcome.flagged);
    final flagged = (await env.txs.byId(b.transactionId!))!;
    expect(flagged.needsReview, isTrue);
    expect(flagged.duplicateOfId, a.transactionId);
    expect(flagged.reviewReason, contains('same day'));
    expect(flagged.transactionHash, contains('#EMAIL:'));
    expect(await env.txs.watchReviewCount().first, 1);
  });

  // FR-07-12
  test('mergeFlagged folds the flagged row into its target', () async {
    final a = await env.ingest(parsed(ref: null));
    final b = await env.ingest(
      parsed(ref: null, source: Source.email, time: t0 + 2 * hour),
    );
    await env.txs.mergeFlagged(b.transactionId!);
    expect(await env.count('transactions'), 1);
    expect((await env.txs.sourcesOf(a.transactionId!)).length, 2);
    expect(await env.txs.watchReviewCount().first, 0);
  });

  test('keepSeparate clears the flag and keeps both rows', () async {
    await env.ingest(parsed(ref: null));
    final b = await env.ingest(
      parsed(ref: null, source: Source.email, time: t0 + 2 * hour),
    );
    await env.txs.keepSeparate(b.transactionId!);
    expect(await env.count('transactions'), 2);
    expect((await env.txs.byId(b.transactionId!))!.needsReview, isFalse);
  });

  // FR-07-07: idempotent per (source, sourceMessageId)
  test('re-ingesting the same message id is skipped', () async {
    final p = parsed();
    final first = await env.ingest(p, id: 'sms-1');
    final again = await env.ingest(p, id: 'sms-1');
    expect(first.outcome, IngestOutcome.inserted);
    expect(again.outcome, IngestOutcome.skipped);
    expect(again.reason, 'already_processed');
    expect(await env.count('transactions'), 1);
    expect(await env.count('transaction_sources'), 1);
  });

  // FR-07-16
  test('batch report counts inserted, merged, flagged and skipped', () async {
    final report = await env.txs.ingestBatch([
      IngestItem(parsed: parsed(ref: null), sourceMessageId: 'a'),
      IngestItem(
        parsed: parsed(ref: null, source: Source.email, time: t0 + minute),
        sourceMessageId: 'b',
      ),
      IngestItem(
        parsed: parsed(ref: null, source: Source.app, time: t0 + 2 * hour),
        sourceMessageId: 'c',
      ),
      IngestItem(parsed: parsed(ref: null), sourceMessageId: 'a'),
    ]);
    expect(report.inserted, 1);
    expect(report.merged, 1);
    expect(report.flagged, 1);
    expect(report.skipped, 1);
    expect(
      report.inserted + report.merged + report.flagged + report.skipped,
      4,
    );
  });

  // FR-07-15, FR-08-09, FR-08-22
  test('delete writes tombstones and ingest respects them', () async {
    final r = await env.ingest(parsed(), id: 'sms-9');
    expect(await env.txs.deleteTransactions([r.transactionId!]), 1);
    expect(await env.count('transactions'), 0);
    expect(await env.count('transaction_sources'), 0);
    expect(await env.count('deleted_messages'), 1);

    final again = await env.ingest(parsed(), id: 'sms-9');
    expect(again.outcome, IngestOutcome.skipped);
    expect(again.reason, 'deleted');
    expect(await env.count('transactions'), 0);
  });

  // FR-08-09: chunks of 900
  test(
    'delete handles more than one tombstone chunk',
    () async {
      final items = [
        for (var i = 0; i < 905; i++)
          IngestItem(
            parsed: parsed(
              amountMinor: 1000 + i * 100,
              ref: 'REF${100000 + i}',
              time: t0 + i * 3 * hour,
            ),
            sourceMessageId: 'bulk-$i',
          ),
      ];
      await env.txs.ingestBatch(items);
      expect(await env.count('transactions'), 905);
      final ids = await env.txs.idsForAccount(1);
      expect(ids.length, 905);
      expect(await env.txs.deleteTransactions(ids), 905);
      expect(await env.count('deleted_messages'), 905);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  // FR-08-17 / TC-08-06: the batch is one DB transaction.
  test('a failing batch rolls back every row', () async {
    await expectLater(
      env.txs.ingestBatch([
        IngestItem(parsed: parsed(), sourceMessageId: 'ok'),
        IngestItem(
          parsed: parsed(amountMinor: 99900, ref: 'ZZZ999999'),
          sourceMessageId: 'bad',
          accountId: 424242, // no such account: foreign key fails
        ),
      ]),
      throwsA(anything),
    );
    expect(await env.count('transactions'), 0);
    expect(await env.count('transaction_sources'), 0);
    expect(await env.count('accounts'), 0);
  });

  // FR-13-07
  test('ingest updates the account balance, older never rewinds', () async {
    await env.ingest(parsed(balance: 5000000), id: 'x1');
    await env.ingest(
      parsed(
        amountMinor: 10000,
        ref: 'REF000002',
        balance: 4000000,
        time: t0 - hour,
      ),
      id: 'x2',
    );
    final a = (await env.accounts.byId(1))!;
    expect(a.latestBalanceMinor, 5000000);
    await env.ingest(
      parsed(
        amountMinor: 20000,
        ref: 'REF000003',
        balance: 4980000,
        time: t0 + hour,
      ),
      id: 'x3',
    );
    expect((await env.accounts.byId(1))!.latestBalanceMinor, 4980000);
  });

  test('credit card message sets the limit, not the balance', () async {
    await env.ingest(
      parsed(
        kind: AccountKind.card,
        last4: '5678',
        limit: 7500000,
        balance: 123,
      ),
    );
    final a = (await env.accounts.byId(1))!;
    expect(a.availableLimitMinor, 7500000);
    expect(a.latestBalanceMinor, isNull);
  });

  test('flagged rows do not move balances or totals', () async {
    await env.ingest(parsed(ref: null));
    await env.ingest(
      parsed(ref: null, source: Source.email, time: t0 + 2 * hour, balance: 1),
    );
    expect((await env.accounts.byId(1))!.latestBalanceMinor, isNull);
    final totals =
        await env.txs.watchTotals(fromMs: t0 - day, toMs: t0 + day).first;
    expect(totals.spentMinor, 25000);
    expect(totals.count, 1);
  });

  // FR-13-01..03
  group('ensureAccount', () {
    test('no last4 means no account', () async {
      final r = await env.ingest(parsed(last4: null));
      expect((await env.txs.byId(r.transactionId!))!.accountId, isNull);
      expect(await env.count('accounts'), 0);
    });

    test('app notifications never create, they attach', () async {
      final r1 = await env.ingest(parsed(source: Source.app, ref: null));
      expect((await env.txs.byId(r1.transactionId!))!.accountId, isNull);
      expect(await env.count('accounts'), 0);
      await env.ingest(
        parsed(amountMinor: 500, ref: 'AAAAAA111', time: t0 + 9 * hour),
      );
      final r2 = await env.ingest(
        parsed(
          amountMinor: 700,
          bank: 'HDFC',
          source: Source.app,
          ref: null,
          time: t0 + 30 * hour,
        ),
      );
      expect((await env.txs.byId(r2.transactionId!))!.accountId, 1);
      expect(await env.count('accounts'), 1);
    });

    test('own phone digits do not create an account', () async {
      final r = await env.txs.ingest(
        IngestItem(
          parsed: parsed(last4: '9876'),
          sourceMessageId: 'p',
          phoneLast4s: const {'9876'},
        ),
      );
      expect((await env.txs.byId(r.transactionId!))!.accountId, isNull);
    });

    test('same bank and digits reuse the account', () async {
      await env.ingest(parsed());
      await env
          .ingest(parsed(amountMinor: 1, ref: 'BBBBBB222', time: t0 + day));
      expect(await env.count('accounts'), 1);
    });

    test('debit card gets typed and a limit creates a credit card', () async {
      await env.ingest(parsed(debitCard: true, last4: '1111'));
      await env.ingest(
        parsed(
          kind: AccountKind.card,
          last4: '2222',
          limit: 100,
          ref: 'CCCCCC333',
        ),
      );
      final accounts = await env.accounts.watchVisible().first;
      expect(
        accounts.map((a) => a.accountType?.name),
        containsAll(['debitCard', 'creditCard']),
      );
    });
  });

  // FR-08-19, TC-08-08: totals in paise
  test('period totals exclude transfers, review rows and use paise', () async {
    Future<void> add(
      int amount,
      TransactionType type,
      Category cat,
      int i,
    ) =>
        env.ingest(
          parsed(
            amountMinor: amount,
            type: type,
            category: cat,
            ref: 'TOT${100000 + i}',
            time: t0 + i * 3 * hour,
          ),
        );
    await add(25050, TransactionType.debit, Category.food, 0);
    await add(10000, TransactionType.debit, Category.groceries, 1);
    await add(500000, TransactionType.credit, Category.salary, 2);
    await add(3000, TransactionType.credit, Category.refund, 3);
    await add(70000, TransactionType.investment, Category.investment, 4);
    await add(900000, TransactionType.transfer, Category.transfer, 5);
    final t =
        await env.txs.watchTotals(fromMs: t0 - hour, toMs: t0 + day).first;
    expect(t.spentMinor, 35050);
    expect(t.incomeMinor, 500000);
    expect(t.refundMinor, 3000);
    expect(t.investedMinor, 70000);
    expect(t.netSpentMinor, 32050);
    expect(t.outMinor, 105050);
    expect(t.count, 6);
    // Outside the period.
    final none = await env.txs
        .watchTotals(fromMs: t0 + 10 * day, toMs: t0 + 11 * day)
        .first;
    expect(none.spentMinor, 0);
  });

  // FR-08-06, TC-08-01
  test('search matches merchant, amount prefix, label, note, reference',
      () async {
    final r1 = await env.ingest(
      parsed(amountMinor: 25050, ref: 'UTR000111'),
    );
    await env.ingest(
      parsed(
        merchant: 'Uber',
        category: Category.transport,
        amountMinor: 40000,
        ref: 'UTR000222',
        time: t0 + 5 * hour,
      ),
    );
    await env.txs.setNote(r1.transactionId!, 'team lunch');

    Future<List<String?>> q(String s) async =>
        (await env.txs.watch(LedgerFilter(query: s)).first)
            .map((t) => t.merchant)
            .toList();

    expect(await q('swig'), ['Swiggy']);
    expect(await q('250'), ['Swiggy']);
    expect(await q('4'), ['Uber']);
    expect(await q('Transport'), ['Uber']);
    expect(await q('lunch'), ['Swiggy']);
    expect(await q('utr000222'), ['Uber']);
    expect(await q('nothing'), isEmpty);
  });

  test('filters: kind, account, category, period, order, limit', () async {
    await env.ingest(parsed(merchant: 'A'));
    await env.ingest(
      parsed(
        merchant: 'B',
        type: TransactionType.credit,
        category: Category.salary,
        amountMinor: 900,
        ref: 'BBBBBB222',
        time: t0 + 4 * hour,
      ),
    );
    await env.ingest(
      parsed(
        merchant: 'C',
        last4: '7777',
        amountMinor: 800,
        ref: 'CCCCCC333',
        time: t0 + 8 * hour,
      ),
    );
    List<String?> names(List<LedgerTx> l) => [for (final t in l) t.merchant];
    expect(
      names(await env.txs.watch(const LedgerFilter()).first),
      ['C', 'B', 'A'],
    );
    expect(
      names(await env.txs.watch(const LedgerFilter(kind: TxKind.income)).first),
      ['B'],
    );
    expect(
      names(await env.txs.watch(const LedgerFilter(kind: TxKind.spends)).first),
      ['C', 'A'],
    );
    expect(
      names(await env.txs.watch(const LedgerFilter(accountId: 2)).first),
      ['C'],
    );
    expect(
      names(
        await env.txs
            .watch(const LedgerFilter(category: Category.salary))
            .first,
      ),
      ['B'],
    );
    expect(
      names(await env.txs.watch(const LedgerFilter(fromMs: t0 + hour)).first),
      ['C', 'B'],
    );
    expect(names(await env.txs.watchRecent(1).first), ['C']);
  });

  // FR-09-06, FR-09-07, FR-09-10
  group('categories', () {
    test('setCategory learns a rule and fixes past OTHER rows', () async {
      final a = await env.ingest(
        parsed(merchant: 'Acme Co', category: Category.other, ref: 'AAAAAA111'),
      );
      final b = await env.ingest(
        parsed(
          merchant: 'Acme Co',
          category: Category.other,
          amountMinor: 999,
          ref: 'BBBBBB222',
          time: t0 + 5 * hour,
        ),
      );
      await env.txs.setCategory([a.transactionId!], Category.shopping);
      expect(
        (await env.txs.byId(b.transactionId!))!.category,
        Category.shopping,
      );
      final rules = (await env.categories.loadRuleSet()).rules;
      expect(rules.single.merchantKey, 'acme co');
      expect(rules.single.manual, isFalse);

      // A new message from that merchant is filed by the rule at ingest.
      final c = await env.ingest(
        parsed(
          merchant: 'Acme Co',
          category: Category.other,
          amountMinor: 777,
          ref: 'CCCCCC333',
          time: t0 + 10 * hour,
        ),
      );
      expect(
        (await env.txs.byId(c.transactionId!))!.category,
        Category.shopping,
      );
    });

    test('a manual rule is never overwritten by learning', () async {
      await env.categories.saveManualRule(
        const MerchantRule(
          merchantKey: 'acme co',
          category: Category.gifts,
          updatedAt: 1,
          manual: true,
        ),
      );
      final a = await env.ingest(parsed(merchant: 'Acme Co'));
      await env.txs.setCategory([a.transactionId!], Category.shopping);
      final rule = (await env.categories.loadRuleSet()).rules.single;
      expect(rule.category, Category.gifts);
    });

    test('transfers are never learned', () async {
      final a = await env.ingest(
        parsed(type: TransactionType.transfer, merchant: 'Own'),
      );
      await env.txs.setCategory([a.transactionId!], Category.transfer);
      expect((await env.categories.loadRuleSet()).rules, isEmpty);
    });

    test('custom category files under OTHER with its id', () async {
      final a = await env.ingest(parsed());
      final id = await env.categories.addCustomCategory(
        name: 'Pets',
        icon: 'pets',
        colorArgb: 0xFF00AA00,
      );
      await env.txs.setCategory(
        [a.transactionId!],
        Category.food,
        customCategoryId: id,
      );
      final tx = (await env.txs.byId(a.transactionId!))!;
      expect(tx.category, Category.other);
      expect(tx.customCategoryId, id);
    });

    test('manual rule apply-to-past with count', () async {
      await env
          .ingest(parsed(merchant: 'Big Basket', category: Category.other));
      await env.ingest(
        parsed(
          merchant: 'BigBasket Pvt',
          category: Category.other,
          ref: 'BBBBBB222',
          amountMinor: 300,
          time: t0 + 5 * hour,
        ),
      );
      const rule = MerchantRule(
        merchantKey: 'bigbasket',
        category: Category.groceries,
        updatedAt: 1,
        matchType: RuleMatch.contains,
        manual: true,
      );
      expect(await env.txs.countRuleMatches(rule), 1);
      expect(await env.txs.applyRuleToPast(rule), 1);
    });
  });

  // FR-08-10
  test('setAccount and setNote edit one row', () async {
    final r = await env.ingest(parsed(last4: null));
    final acc = await env.accounts.create(_icici);
    await env.txs.setAccount(r.transactionId!, acc);
    await env.txs.setNote(r.transactionId!, '  hello ');
    final tx = (await env.txs.byId(r.transactionId!))!;
    expect(tx.accountId, acc);
    expect(tx.accountLast4, '4321');
    expect(tx.note, 'hello');
  });

  test('manual entry is ingested with its account', () async {
    final acc = (await env.accounts.create(_icici))!;
    final r = await env.txs.addManual(
      amountMinor: 12345,
      type: TransactionType.debit,
      timestamp: t0,
      accountId: acc,
      merchant: 'Chai',
      note: 'cash',
    );
    expect(r.outcome, IngestOutcome.inserted);
    final tx = (await env.txs.byId(r.transactionId!))!;
    expect(tx.accountId, acc);
    expect(tx.note, 'cash');
    expect((await env.txs.sourcesOf(tx.id)).single.source, Source.manual);
  });

  test('review pairs list flagged rows with their target', () async {
    final a = await env.ingest(parsed(ref: null));
    await env.ingest(
      parsed(ref: null, source: Source.email, time: t0 + 2 * hour),
    );
    final pairs = await env.txs.watchReviewPairs().first;
    expect(pairs.single.target!.id, a.transactionId);
    expect(pairs.single.flagged.needsReview, isTrue);
  });

  test('foreign currency rows have no INR value yet', () async {
    final r = await env.ingest(parsed(currency: 'USD'));
    expect((await env.txs.byId(r.transactionId!))!.inrMinor, isNull);
  });
}

const int day = 24 * hour;

const _icici = NewAccount(
  kind: AccountKind.account,
  bankName: 'ICICI Bank',
  last4: '4321',
);

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_views.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  const from = t0 - 10 * 24 * hour;
  const to = t0 + 10 * 24 * hour;

  test('FR-10-18, FR-10-19: totals count the bill payment, not the purchase',
      () async {
    await env.ingest(
      parsed(
        amountMinor: 200000,
        merchant: 'Amazon',
        ref: 'c1',
        last4: '9999',
        kind: AccountKind.card,
        bank: 'ICICI Bank',
        category: Category.shopping,
      ),
    );
    await env.ingest(parsed(amountMinor: 30000, ref: 'b1'));
    // Bank payment of the card bill, then the card's payment record.
    await env.ingest(
      parsed(
        amountMinor: 150000,
        merchant: 'ICICI card',
        ref: 'b2',
        time: t0 + 2 * hour,
      ),
    );
    await env.ingest(
      parsed(
        amountMinor: 150000,
        type: TransactionType.transfer,
        ref: 'c2',
        last4: '9999',
        kind: AccountKind.card,
        bank: 'ICICI Bank',
        merchant: null,
        time: t0 + 3 * hour,
        category: Category.transfer,
      ),
    );
    final t = await env.txs.watchTotals(fromMs: from, toMs: to).first;
    expect(t.cardPurchasesMinor, 200000);
    expect(t.cardPaymentsMinor, 150000);
    expect(t.spentMinor, 180000);
  });

  test('FR-20-23: book scope follows the account usage', () async {
    await env.ingest(parsed(amountMinor: 10000, ref: 'p1'));
    await env.ingest(
      parsed(amountMinor: 70000, ref: 'p2', last4: '5555', bank: 'Axis Bank'),
    );
    final biz = (await env.accounts.watchVisible().first)
        .firstWhere((a) => a.last4 == '5555');
    await env.db.customStatement(
      "UPDATE accounts SET usage = 'BUSINESS' WHERE id = ${biz.id}",
    );
    expect(biz.usage, AccountUsage.personal);
    final all = await env.txs.watchTotals(fromMs: from, toMs: to).first;
    final b = await env.txs
        .watchTotals(fromMs: from, toMs: to, usage: 'BUSINESS')
        .first;
    final p = await env.txs
        .watchTotals(fromMs: from, toMs: to, usage: 'PERSONAL')
        .first;
    expect([all.spentMinor, b.spentMinor, p.spentMinor], [80000, 70000, 10000]);
    final rows =
        await env.txs.watch(const LedgerFilter(usage: 'BUSINESS')).first;
    expect(rows, hasLength(1));
    final cards = await env.txs
        .watch(const LedgerFilter(accountKind: AccountKind.card))
        .first;
    expect(cards, isEmpty);
  });

  test('FR-08-24: remember payee files later rows under the account', () async {
    await env.ingest(parsed(amountMinor: 10000, ref: 'r1', merchant: 'Zomato'));
    await env.ingest(
      parsed(
        amountMinor: 20000,
        ref: 'r2',
        last4: '7777',
        bank: 'SBI',
        merchant: 'Other',
      ),
    );
    final accs = await env.accounts.watchVisible().first;
    final target = accs.firstWhere((a) => a.last4 == '7777');
    final first = (await env.txs.watch(const LedgerFilter()).first)
        .firstWhere((t) => t.merchant == 'Zomato');
    await env.txs.setAccount(first.id, target.id, rememberPayee: true);
    await env.ingest(
      parsed(
        amountMinor: 33300,
        ref: 'r3',
        merchant: 'Zomato',
        time: t0 + hour,
      ),
    );
    final next = (await env.txs.watch(const LedgerFilter()).first)
        .firstWhere((t) => t.amountMinor == 33300);
    expect(next.accountId, target.id);
  });

  test('FR-08-25: transfer to a card is a bill payment on the bank leg',
      () async {
    await env.ingest(parsed(amountMinor: 1000, ref: 'x1'));
    await env.ingest(
      parsed(
        amountMinor: 1000,
        ref: 'x2',
        last4: '8888',
        kind: AccountKind.card,
        bank: 'HSBC',
        merchant: 'Shop',
      ),
    );
    final accs = await env.accounts.watchVisible().first;
    final bank = accs.firstWhere((a) => a.last4 == '1234');
    final cardAcc = accs.firstWhere((a) => a.last4 == '8888');
    await env.txs.addOwnTransfer(
      fromAccountId: bank.id,
      toAccountId: cardAcc.id,
      amountMinor: 55000,
      timestamp: t0,
    );
    final t = await env.txs.watchTotals(fromMs: from, toMs: to).first;
    expect(t.cardPaymentsMinor, 55000);
    expect(t.spentMinor, 1000 + 55000);
  });

  test('FR-08-23: By category merges card and account spends', () async {
    await env.ingest(parsed(amountMinor: 10000, ref: 'g1'));
    await env.ingest(
      parsed(
        ref: 'g2',
        last4: '9999',
        kind: AccountKind.card,
        bank: 'ICICI Bank',
      ),
    );
    await env.ingest(
      parsed(
        amountMinor: 5000,
        ref: 'g3',
        type: TransactionType.credit,
        category: Category.refund,
        last4: '9999',
        kind: AccountKind.card,
        bank: 'ICICI Bank',
        merchant: 'Swiggy refund',
      ),
    );
    final rows = await env.txs.watch(const LedgerFilter()).first;
    final groups = groupByCategory(rows);
    final g = groups.first;
    expect(g.category, Category.food);
    expect(g.accountMinor, 10000);
    expect(g.cardMinor, 25000);
    expect(g.totalMinor, 35000);
    // The card refund shows as a negative Refund group on the card side.
    expect(groups.last.category, Category.refund);
    expect(groups.last.cardMinor, -5000);
  });
}

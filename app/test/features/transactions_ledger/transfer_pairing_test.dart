import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

const int _day = 24 * hour;

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<LedgerTx> row(int id) async => (await env.txs.byId(id))!;

  Future<int> ingest(
    int amount,
    TransactionType type,
    String last4,
    int time, {
    String bank = 'HDFC Bank',
    AccountKind kind = AccountKind.account,
    Category cat = Category.other,
    String? ref,
  }) async =>
      (await env.ingest(
        parsed(
          amountMinor: amount,
          type: type,
          last4: last4,
          time: time,
          bank: bank,
          kind: kind,
          category: cat,
          ref: ref,
          merchant: 'X$last4',
        ),
      ))
          .transactionId!;

  // FR-08-14, FR-08-15, TC-08-02: own-account window is +-2 h.
  test('debit and credit on two own accounts pair within 2 h', () async {
    final a = await ingest(500000, TransactionType.debit, '1111', t0);
    final b = await ingest(
      500000,
      TransactionType.credit,
      '2222',
      t0 + 2 * hour,
      bank: 'ICICI Bank',
    );
    for (final id in [a, b]) {
      final t = await row(id);
      expect(t.type, TransactionType.transfer);
      expect(t.note, 'Self transfer between your accounts');
    }
    final totals =
        await env.txs.watchTotals(fromMs: t0 - _day, toMs: t0 + _day).first;
    expect(totals.spentMinor, 0);
    expect(totals.incomeMinor, 0);
  });

  test('outside 2 h or a different amount stays spend and income', () async {
    final a = await ingest(500000, TransactionType.debit, '1111', t0);
    final b = await ingest(
      500000,
      TransactionType.credit,
      '2222',
      t0 + 2 * hour + minute,
      bank: 'ICICI Bank',
    );
    final c = await ingest(
      500001,
      TransactionType.credit,
      '3333',
      t0,
      bank: 'SBI',
    );
    expect((await row(a)).type, TransactionType.debit);
    expect((await row(b)).type, TransactionType.credit);
    expect((await row(c)).type, TransactionType.credit);
  });

  test('same account never pairs with itself', () async {
    await ingest(500000, TransactionType.debit, '1111', t0);
    final b = await ingest(500000, TransactionType.credit, '1111', t0 + hour);
    expect((await row(b)).type, TransactionType.credit);
  });

  // FR-08-14: bank debit after the card side states the payment.
  test('bank debit pairs with a card-side payment within 5 days', () async {
    final card = await ingest(
      1234500,
      TransactionType.transfer,
      '5678',
      t0,
      kind: AccountKind.card,
      cat: Category.transfer,
    );
    final bank = await ingest(
      1234500,
      TransactionType.debit,
      '1111',
      t0 + 5 * _day,
    );
    expect((await row(bank)).type, TransactionType.transfer);
    expect((await row(bank)).note, 'Credit card bill payment');
    expect((await row(card)).type, TransactionType.transfer);
  });

  test('bank debit 5 days and a minute after the card side stays spend',
      () async {
    await ingest(
      1234500,
      TransactionType.transfer,
      '5678',
      t0,
      kind: AccountKind.card,
      cat: Category.transfer,
    );
    final late = await ingest(
      1234500,
      TransactionType.debit,
      '1112',
      t0 + 5 * _day + minute,
    );
    expect((await row(late)).type, TransactionType.debit);
  });

  // FR-08-14: the card side arrives last and pulls the nearest bank debit.
  test('card-side payment marks the nearest bank debit', () async {
    final far = await ingest(
      900000,
      TransactionType.debit,
      '1111',
      t0 - 3 * _day,
      ref: 'r1',
    );
    final near = await ingest(
      900000,
      TransactionType.debit,
      '1112',
      t0 - _day,
      ref: 'r2',
    );
    await ingest(
      900000,
      TransactionType.transfer,
      '5678',
      t0,
      kind: AccountKind.card,
      cat: Category.transfer,
    );
    expect((await row(near)).type, TransactionType.transfer);
    expect((await row(far)).type, TransactionType.debit);
  });

  // FR-08-15: EMI on a loan account pairs with the bank debit (3 days).
  test('pairEmi marks the loan side, bank debit stays the spend', () async {
    final loan = await env.accounts.create(
      const NewAccount(
        kind: AccountKind.account,
        bankName: 'Bajaj Finserv',
        last4: '9999',
        accountType: AccountType.loan,
      ),
    );
    final bank = await ingest(
      1500000,
      TransactionType.debit,
      '1111',
      t0,
      cat: Category.emiLoan,
    );
    final l = (await env.ingest(
      parsed(
        amountMinor: 1500000,
        last4: '9999',
        bank: 'Bajaj Finserv',
        category: Category.emiLoan,
        time: t0 + 3 * _day,
        ref: 'loanref',
      ),
      accountId: loan,
    ))
        .transactionId!;
    expect((await row(l)).type, TransactionType.transfer);
    expect((await row(l)).note, 'EMI also debited from your bank account');
    expect((await row(bank)).type, TransactionType.debit);
  });

  // FR-08-13, TC-08-03
  test('addOwnTransfer writes two legs and a bank SMS folds into one',
      () async {
    final from = (await env.accounts.create(
      const NewAccount(
        kind: AccountKind.account,
        bankName: 'HDFC Bank',
        last4: '1234',
      ),
    ))!;
    final to = (await env.accounts.create(
      const NewAccount(
        kind: AccountKind.account,
        bankName: 'ICICI Bank',
        last4: '4321',
      ),
    ))!;
    final ids = await env.txs.addOwnTransfer(
      fromAccountId: from,
      toAccountId: to,
      amountMinor: 500000,
      timestamp: t0,
    );
    expect(ids.length, 2);
    final out = await row(ids[0]);
    expect(out.type, TransactionType.transfer);
    expect(out.merchant, 'To ICICI Bank ••4321');
    expect((await row(ids[1])).merchant, 'From HDFC Bank ••1234');
    expect(
      (await env.txs.sourcesOf(ids[0])).single.sourceMessageId,
      startsWith('xfer-out:'),
    );
    final r = await env.ingest(
      parsed(amountMinor: 500000, time: t0 + 35 * hour, ref: 'x1'),
    );
    expect(r.transactionId, ids[0]);
    expect(await env.count('transactions'), 2);
    final totals =
        await env.txs.watchTotals(fromMs: t0 - _day, toMs: t0 + 3 * _day).first;
    expect(totals.spentMinor, 0);
    expect(totals.incomeMinor, 0);
    // 36 h boundary: a message 37 h later is a new row.
    final late = await env.ingest(
      parsed(
        amountMinor: 500000,
        time: t0 + 37 * hour,
        ref: 'x2',
        merchant: 'Late',
      ),
    );
    expect(late.transactionId, isNot(ids[0]));
  });

  // FR-08-08: manual merge keeps the oldest row and moves sources.
  test('mergeRows folds selected rows into the oldest', () async {
    final a = await ingest(10000, TransactionType.debit, '1111', t0, ref: 'a');
    final b = await ingest(
      10000,
      TransactionType.debit,
      '1111',
      t0 + 3 * hour,
      ref: 'b',
    );
    expect(b, isNot(a));
    expect(await env.txs.mergeRows([a, b]), a);
    expect(await env.count('transactions'), 1);
    expect((await env.txs.sourcesOf(a)).length, 2);
    expect(await env.txs.mergeRows([a]), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

Future<AccountWithActivity> one(TestEnv env, int id) async {
  final list = await env.accounts
      .watchWithActivity(monthStartMs: t0 - 30 * day, monthEndMs: t0 + 30 * day)
      .first;
  return list.firstWhere((a) => a.account.id == id);
}

const int day = 24 * hour;

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  // FR-13-05
  test('create returns null for a duplicate bank and last4', () async {
    const a = NewAccount(
      kind: AccountKind.account,
      bankName: 'HDFC Bank',
      last4: '1234',
      balanceMinor: 100000,
    );
    expect(await env.accounts.create(a), 1);
    expect(await env.accounts.create(a), isNull);
    final acc = (await env.accounts.byId(1))!;
    expect(acc.manualBalanceMinor, 100000);
    expect(acc.manualBalanceAt, env.clock);
  });

  // FR-13-07: reported 50,000 then -250, +1,000 => 50,750 (estimated)
  test('balance = reported + later signed changes', () async {
    await env.ingest(parsed(balance: 5000000, ref: 'AAAAAA111'));
    await env.ingest(
      parsed(ref: 'BBBBBB222', time: t0 + hour),
    );
    await env.ingest(
      parsed(
        amountMinor: 100000,
        type: TransactionType.credit,
        ref: 'CCCCCC333',
        time: t0 + 2 * hour,
      ),
    );
    final a = await one(env, 1);
    expect(a.currentBalanceMinor, 5075000);
    expect(a.balanceIsEstimated, isTrue);
    expect(a.usesManual, isFalse);
    expect(a.monthSpent, 50000);
    expect(a.transactionCount, 3);
  });

  test('typed balance wins when newer than the reported one', () async {
    await env.ingest(parsed(balance: 5000000, ref: 'AAAAAA111'));
    await env.accounts.setManualBalance(1, 5200000, t0 + 3 * hour);
    await env.ingest(
      parsed(amountMinor: 20000, ref: 'BBBBBB222', time: t0 + 4 * hour),
    );
    final a = await one(env, 1);
    expect(a.usesManual, isTrue);
    expect(a.currentBalanceMinor, 5180000);
    // A newer bank figure takes over again.
    await env.ingest(
      parsed(
        amountMinor: 1000,
        ref: 'CCCCCC333',
        balance: 5170000,
        time: t0 + 5 * hour,
      ),
    );
    final b = await one(env, 1);
    expect(b.usesManual, isFalse);
    expect(b.currentBalanceMinor, 5170000);
  });

  test('review rows and transfers without direction do not move balance',
      () async {
    await env.ingest(parsed(balance: 1000000, ref: 'AAAAAA111'));
    await env.ingest(
      parsed(
        amountMinor: 50000,
        type: TransactionType.transfer,
        category: Category.transfer,
        ref: 'BBBBBB222',
        time: t0 + hour,
      ),
    );
    expect((await one(env, 1)).currentBalanceMinor, 1000000);
  });

  test('card transfer (bill payment) frees limit', () async {
    await env.ingest(
      parsed(
        kind: AccountKind.card,
        last4: '5678',
        limit: 4000000,
        ref: 'AAAAAA111',
      ),
    );
    await env.ingest(
      parsed(
        kind: AccountKind.card,
        last4: '5678',
        amountMinor: 100000,
        type: TransactionType.transfer,
        category: Category.transfer,
        ref: 'BBBBBB222',
        time: t0 + hour,
      ),
    );
    expect((await one(env, 1)).currentBalanceMinor, 4100000);
  });

  // FR-13-08, FR-13-10
  test('merge is display-only and rolls figures into the target', () async {
    await env.ingest(parsed(last4: '1111', ref: 'AAAAAA111', balance: 100000));
    await env.ingest(
      parsed(
        last4: '0111',
        amountMinor: 5000,
        ref: 'BBBBBB222',
        time: t0 + 3 * hour,
      ),
    );
    await env.accounts.setMergedInto(2, 1);
    final visible = await env.accounts.watchVisible().first;
    expect(visible.map((a) => a.id), [1]);
    final a = await one(env, 1);
    expect(a.transactionCount, 2);
    expect(a.currentBalanceMinor, 95000);
    await env.accounts.setMergedInto(2, null);
    expect((await env.accounts.watchVisible().first).length, 2);
  });

  test('hide removes from the visible list and totals', () async {
    await env.ingest(parsed());
    await env.accounts.setHidden(1, hidden: true);
    expect(await env.accounts.watchVisible().first, isEmpty);
    expect((await env.accounts.watchHidden().first).single.id, 1);
    await env.accounts.setHidden(1, hidden: false);
    expect((await env.accounts.watchVisible().first).length, 1);
  });

  // FR-13-11: transactions stay, account-less
  test('delete keeps transactions without an account', () async {
    final r = await env.ingest(parsed());
    await env.accounts.delete(1);
    expect(await env.accounts.byId(1), isNull);
    final tx = (await env.txs.byId(r.transactionId!))!;
    expect(tx.accountId, isNull);
  });

  test('rename trims and clears', () async {
    await env.ingest(parsed());
    await env.accounts.rename(1, '  Salary a/c ');
    expect((await env.accounts.byId(1))!.label, 'Salary a/c');
    await env.accounts.rename(1, ' ');
    expect((await env.accounts.byId(1))!.label, 'HDFC Bank ••1234');
  });

  test('debit card balance goes to the linked account', () async {
    await env.ingest(parsed(last4: '1111', ref: 'AAAAAA111'));
    await env.ingest(
      parsed(
        last4: '2222',
        debitCard: true,
        amountMinor: 700,
        ref: 'BBBBBB222',
        balance: 777000,
        time: t0 + 2 * hour,
      ),
    );
    // Link card (2) to account (1), then another debit-card message.
    await env.db.customStatement(
      'UPDATE accounts SET linked_account_id = 1 WHERE id = 2',
    );
    await env.ingest(
      parsed(
        last4: '2222',
        debitCard: true,
        amountMinor: 800,
        ref: 'CCCCCC333',
        balance: 888000,
        time: t0 + 4 * hour,
      ),
    );
    expect((await env.accounts.byId(1))!.latestBalanceMinor, 888000);
  });
}

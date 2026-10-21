import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/forex_rates/data/forex_repository_impl.dart';
import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';
import 'package:parser_core/parser_core.dart' show AccountKind;

import '../../support/parsed.dart';
import '../../support/test_env.dart';

// FR-23-04..06, FR-23-10: triggers and recompute keep inrMinor current.
void main() {
  late TestEnv env;
  late ForexRepositoryImpl forex;
  setUp(() {
    env = TestEnv();
    forex = ForexRepositoryImpl(env.db);
  });
  tearDown(() => env.close());

  Future<int?> inr(String hash) async => (await env.db.customSelect(
        'SELECT inr_minor AS v FROM transactions WHERE transaction_hash = ?1',
        variables: [Variable.withString(hash)],
      ).getSingle())
          .read<int?>('v');

  int istDay(int ms) => (ms + 19800000) ~/ 86400000;

  test('INR row gets amountMinor on insert (G)', () async {
    final p = parsed(amountMinor: 45000);
    await env.ingest(p);
    expect(await inr(p.transactionHash), 45000);
  });

  test('foreign row is NULL without a rate, priced after upsert (A, E)',
      () async {
    final p = parsed(amountMinor: 20000, currency: 'USD', ref: 'r1');
    await env.ingest(p);
    expect(await inr(p.transactionHash), isNull);
    expect((await forex.watchForeign().first).single.unpriced, 1);
    await forex.upsert(
      ForexRate(currency: 'usd', day: istDay(t0), inrPerUnit: 83.10),
    );
    expect(await inr(p.transactionHash), 1662000);
    expect((await forex.watchForeign().first).single.unpriced, 0);
    await forex.delete('USD', istDay(t0));
    expect(await inr(p.transactionHash), isNull);
  });

  test('markup applies on insert and on recompute (B)', () async {
    final acc = (await env.accounts.create(
      const NewAccount(
        kind: AccountKind.account,
        bankName: 'HDFC Bank',
        last4: '1234',
      ),
    ))!;
    await env.db.customStatement(
      'UPDATE accounts SET forex_markup_bps = 413 WHERE id = $acc',
    );
    await forex.upsert(
      ForexRate(currency: 'USD', day: istDay(t0), inrPerUnit: 83.10),
    );
    final p = parsed(amountMinor: 20000, currency: 'USD', ref: 'r2');
    await env.ingest(p, accountId: acc);
    expect(await inr(p.transactionHash), 1730641);
    await env.db.customStatement(
      'UPDATE accounts SET forex_markup_bps = 0 WHERE id = $acc',
    );
    await forex.recompute();
    expect(await inr(p.transactionHash), 1662000);
  });

  test('nearest day wins, earlier day on a tie (C, D)', () async {
    final day = istDay(t0);
    await forex.upsert(
      ForexRate(currency: 'USD', day: day - 11, inrPerUnit: 83),
    );
    await forex.upsert(
      ForexRate(currency: 'USD', day: day + 8, inrPerUnit: 84),
    );
    final p = parsed(amountMinor: 100, currency: 'USD', ref: 'r3');
    await env.ingest(p);
    expect(await inr(p.transactionHash), 8400);
    await forex.delete('USD', day + 8);
    await forex.upsert(
      ForexRate(currency: 'USD', day: day + 11, inrPerUnit: 90),
    );
    expect(await inr(p.transactionHash), 8300);
    expect((await forex.rateFor('USD', day))!.day, day - 11);
    expect((await forex.latest('USD'))!.day, day + 11);
  });

  test('amount update re-fires the trigger', () async {
    await forex.upsert(
      ForexRate(currency: 'USD', day: istDay(t0), inrPerUnit: 80),
    );
    final p = parsed(amountMinor: 100, currency: 'USD', ref: 'r4');
    await env.ingest(p);
    await env.db.customStatement(
      "UPDATE transactions SET amount_minor = 300 WHERE transaction_hash = '${p.transactionHash}'",
    );
    expect(await inr(p.transactionHash), 24000);
  });

  test('invalid rates are rejected', () async {
    expect(
      () =>
          forex.upsert(const ForexRate(currency: 'US', day: 1, inrPerUnit: 1)),
      throwsArgumentError,
    );
    expect(
      () =>
          forex.upsert(const ForexRate(currency: 'USD', day: 1, inrPerUnit: 0)),
      throwsArgumentError,
    );
  });
}

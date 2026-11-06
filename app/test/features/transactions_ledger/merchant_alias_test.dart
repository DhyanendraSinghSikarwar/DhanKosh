// Merchant alias: a chosen name shown for every row of a payee (FR-09-20).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  test('an alias shows on every row of the payee and can be removed', () async {
    final a = await env.ingest(
      parsed(amountMinor: 10000, merchant: 'SWIGGY BANGALORE', ref: 'a'),
    );
    final b = await env.ingest(
      parsed(
        amountMinor: 20000,
        merchant: 'SWIGGY BANGALORE',
        ref: 'b',
        time: t0 + hour,
      ),
    );
    await env.ingest(
      parsed(
        amountMinor: 5000,
        merchant: 'ZOMATO',
        ref: 'c',
        time: t0 + 2 * hour,
      ),
    );

    await env.txs.setMerchantAlias(a.transactionId!, '  Food delivery ');
    expect((await env.txs.byId(a.transactionId!))!.title, 'Food delivery');
    expect((await env.txs.byId(b.transactionId!))!.title, 'Food delivery');
    expect(
      (await env.txs.byId(a.transactionId!))!.merchant,
      'SWIGGY BANGALORE',
    );

    final titles =
        (await env.txs.watch(const LedgerFilter()).first).map((t) => t.title);
    expect(titles.where((t) => t == 'Food delivery'), hasLength(2));
    expect(titles, contains('ZOMATO'));

    await env.txs.setMerchantAlias(b.transactionId!, '');
    expect((await env.txs.byId(a.transactionId!))!.title, 'SWIGGY BANGALORE');
  });
}

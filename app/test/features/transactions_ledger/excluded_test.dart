// Leave a transaction out of totals, keep its balance effect (FR-10-24).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  const from = t0 - 10 * 24 * hour;
  const to = t0 + 10 * 24 * hour;

  test('an excluded debit leaves totals and spend counts, the row stays',
      () async {
    final a = await env.ingest(parsed(amountMinor: 30000, ref: 'a'));
    await env.ingest(parsed(amountMinor: 50000, ref: 'b', time: t0 + hour));
    expect(
      (await env.txs.watchTotals(fromMs: from, toMs: to).first).spentMinor,
      80000,
    );

    await env.txs.setExcluded([a.transactionId!], excluded: true);
    final row = (await env.txs.byId(a.transactionId!))!;
    expect(row.excluded, isTrue);
    expect(SpendCalc.counts(row), isFalse);
    expect(
      (await env.txs.watchTotals(fromMs: from, toMs: to).first).spentMinor,
      50000,
    );
    expect(await env.txs.watch(const LedgerFilter()).first, hasLength(2));

    await env.txs.setExcluded([a.transactionId!], excluded: false);
    expect(
      (await env.txs.watchTotals(fromMs: from, toMs: to).first).spentMinor,
      80000,
    );
  });
}

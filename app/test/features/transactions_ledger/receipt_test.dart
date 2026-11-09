// Receipt photo reference on a transaction (FR-08-31).
import 'package:flutter_test/flutter_test.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  test('a receipt file name is saved and cleared', () async {
    final env = TestEnv();
    addTearDown(env.close);
    final r = await env.ingest(parsed(amountMinor: 1000, ref: 'a'));
    expect((await env.txs.byId(r.transactionId!))!.receipt, isNull);
    await env.txs.setReceipt(r.transactionId!, '7-1.jpg');
    expect((await env.txs.byId(r.transactionId!))!.receipt, '7-1.jpg');
    await env.txs.setReceipt(r.transactionId!, null);
    expect((await env.txs.byId(r.transactionId!))!.receipt, isNull);
  });
}

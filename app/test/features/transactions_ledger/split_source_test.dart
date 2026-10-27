import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/test_env.dart';

const _body = 'Sent Rs.250.00\nFrom HDFC Bank A/C *1234\nTo SWIGGY\n'
    'On 25/09/26\nRef 526812345678\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  // FR-07-13
  test('splitSource moves one message into its own row', () async {
    final p = (parse(Source.sms, 'VM-HDFCBK', _body, 1790310600000) as Parsed)
        .transaction;
    final a = await env.ingest(p, id: 's1', raw: _body);
    final b = await env.ingest(p, id: 's2', raw: _body);
    expect(b.outcome, IngestOutcome.merged);
    final srcs = await env.txs.sourcesOf(a.transactionId!);
    expect(srcs, hasLength(2));

    final id = await env.txs.splitSource(a.transactionId!, srcs.last.id);
    expect(id, isNotNull);
    expect(await env.count('transactions'), 2);
    expect(await env.txs.sourcesOf(a.transactionId!), hasLength(1));
    expect((await env.txs.sourcesOf(id!)).single.id, srcs.last.id);
    expect((await env.txs.byId(id))!.amountMinor, 25000);

    // A row with one message cannot be split, and neither without text.
    expect(await env.txs.splitSource(id, srcs.last.id), isNull);
    expect(await env.txs.splitSource(a.transactionId!, 9999), isNull);
  });
}

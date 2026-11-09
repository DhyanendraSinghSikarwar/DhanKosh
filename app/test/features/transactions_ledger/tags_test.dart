// Tags on transactions (FR-08-29).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/transactions_ledger/data/transaction_repository_impl.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  test('cleanTags trims, drops #, dedupes ignoring case, limits', () {
    expect(
      TransactionRepositoryImpl.cleanTags(
        [' #Trip ', 'trip', '', 'Work', 'x' * 40],
      ),
      ['Trip', 'Work', 'x' * 30],
    );
    expect(
      TransactionRepositoryImpl.cleanTags([for (var i = 0; i < 15; i++) 't$i']),
      hasLength(10),
    );
  });

  test('tags are saved, listed by use, found by search, and tidied up',
      () async {
    final a = await env.ingest(parsed(amountMinor: 1000, ref: 'a'));
    final b = await env.ingest(
      parsed(amountMinor: 2000, ref: 'b', time: t0 + hour),
    );
    await env.txs.setTags(a.transactionId!, ['trip', 'gift']);
    await env.txs.setTags(b.transactionId!, ['trip']);
    expect((await env.txs.byId(a.transactionId!))!.tags, ['gift', 'trip']);
    expect(await env.txs.allTags(), ['trip', 'gift']);

    final byTag = await env.txs.watch(const LedgerFilter(query: '#trip')).first;
    expect(byTag, hasLength(2));
    final food = await env.txs.watch(const LedgerFilter(query: 'gift')).first;
    expect(food.single.id, a.transactionId);

    await env.txs.setTags(a.transactionId!, []);
    await env.txs.setTags(b.transactionId!, []);
    expect(await env.txs.allTags(), isEmpty);
  });
}

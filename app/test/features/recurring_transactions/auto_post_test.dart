// Regular payments that add themselves (FR-12-22, ADR-0013).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/recurring_transactions/data/recurring_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_auto_post.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late RecurringRepositoryImpl items;
  final created = DateTime.utc(2026, 9).millisecondsSinceEpoch;
  setUp(() {
    env = TestEnv();
    items = RecurringRepositoryImpl(env.db, now: () => created);
  });
  tearDown(() => env.close());

  RecurringDraft rent({bool auto = true, int day = 5}) => RecurringDraft(
        name: 'Rent',
        amountMinor: 1500000,
        frequency: RecurringFrequency.monthly,
        dayOfMonth: day,
        category: Category.rent,
        autoPost: auto,
      );

  test('dueOn: latest passed date, not before creation, not too old', () async {
    final id = await items.add(rent());
    final m = (await items.all()).single;
    expect(m.id, id);
    expect(
      RecurringAutoPost.dueOn(m, DateTime.utc(2026, 11, 9)),
      DateTime.utc(2026, 11, 5),
    );
    expect(
      RecurringAutoPost.dueOn(m, DateTime.utc(2026, 11, 3)),
      DateTime.utc(2026, 10, 5),
    );
    expect(RecurringAutoPost.dueOn(m, DateTime.utc(2026, 9, 3)), isNull);
    expect(
      RecurringAutoPost.dueOn(m, DateTime.utc(2026, 12, 20)),
      DateTime.utc(2026, 12, 5),
    );
  });

  test('books once per due date, off by default, deleted rows stay gone',
      () async {
    await items.add(rent(auto: false, day: 3));
    final run = RecurringAutoPost(items, env.txs);
    final today = DateTime.utc(2026, 11, 9);
    expect(await run.run(today), 0);

    await items.add(rent());
    expect(await run.run(today), 1);
    expect(await run.run(today), 0);
    final rows = await env.db.select(env.db.transactions).get();
    expect(rows, hasLength(1));
    expect(rows.single.merchant, 'Rent');
    expect(rows.single.amountMinor, 1500000);
    expect(rows.single.type, 'DEBIT');

    await env.txs.deleteTransactions([rows.single.id]);
    expect(await run.run(today), 0);
    expect(await env.db.select(env.db.transactions).get(), isEmpty);

    // The next month's date books again.
    expect(await run.run(DateTime.utc(2026, 12, 6)), 1);
  });
}

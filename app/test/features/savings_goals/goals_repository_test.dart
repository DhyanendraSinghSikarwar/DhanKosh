// Goals, SIPs and MF order stores on an in-memory database (FR-36-01,
// FR-36-02, FR-12-19, FR-16-22).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/recurring_transactions/data/sip_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';
import 'package:hisaab/features/savings_goals/data/goal_repository_impl.dart';
import 'package:hisaab/features/savings_goals/domain/goal.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  test('goals: add, edit, contribute, delete cascades (FR-36-01/02)', () async {
    final repo = GoalRepositoryImpl(env.db, now: () => 5);
    final id = await repo.addGoal(
      const GoalDraft(name: ' Trip ', targetMinor: 5000000, targetDay: 21000),
    );
    var goals = await repo.watchGoals().first;
    expect(goals.single.name, 'Trip');
    expect(goals.single.targetDay, 21000);
    await repo.updateGoal(
      id,
      const GoalDraft(name: 'Trip', targetMinor: 6000000),
    );
    goals = await repo.watchGoals().first;
    expect(goals.single.targetMinor, 6000000);
    expect(goals.single.targetDay, isNull);

    await repo.addContribution(id, 100000, 20500, note: 'bonus');
    await repo.addContribution(id, 50000, 20510);
    final cs = await repo.watchContributions().first;
    expect(cs.map((c) => c.amountMinor), [100000, 50000]);
    expect(cs.first.note, 'bonus');

    await repo.deleteContribution(cs.first.id);
    expect(await env.count('goal_contributions'), 1);
    await repo.deleteGoal(id);
    expect(await env.count('goals'), 0);
    expect(await env.count('goal_contributions'), 0);
    // Tracking only: the ledger is untouched.
    expect(await env.count('transactions'), 0);
  });

  test('goals reject bad input', () async {
    final repo = GoalRepositoryImpl(env.db);
    expect(
      () => repo.addGoal(const GoalDraft(name: '', targetMinor: 1)),
      throwsArgumentError,
    );
    expect(() => repo.addContribution(1, 0, 1), throwsArgumentError);
  });

  test('SIPs: add, edit, delete; weekly keeps weekday only (FR-12-19)',
      () async {
    final repo = SipRepositoryImpl(env.db, now: () => 9);
    final id = await repo.add(
      const SipDraft(
        name: 'Index Fund',
        amountMinor: 500000,
        frequency: SipFrequency.weekly,
        startDay: 20000,
        dayOfMonth: 5,
        weekday: 3,
      ),
    );
    var s = (await repo.watchAll().first).single;
    expect(s.frequency, SipFrequency.weekly);
    expect(s.weekday, 3);
    expect(s.dayOfMonth, isNull);
    await repo.update(
      id,
      const SipDraft(
        name: 'Index Fund',
        amountMinor: 700000,
        frequency: SipFrequency.monthly,
        startDay: 20000,
        dayOfMonth: 7,
      ),
    );
    s = (await repo.watchAll().first).single;
    expect(s.amountMinor, 700000);
    expect(s.dayOfMonth, 7);
    expect(s.weekday, isNull);
    await repo.delete(id);
    expect(await env.count('sips'), 0);
    expect(
      () => repo.add(
        const SipDraft(
          name: '',
          amountMinor: 1,
          frequency: SipFrequency.daily,
          startDay: 1,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('MF orders are kept once per claim (FR-16-22)', () async {
    final holdings = HoldingRepositoryImpl(env.db);
    MfOrderEntry order(int at) => MfOrderEntry(
          schemeName: 'Sample Index Fund',
          identifier: 'MF:sample index fund',
          at: at,
          amountMinor: 500000,
          units: 10,
          nav: 50,
        );
    expect(await holdings.recordMfOrder(order(1000), claimKey: 'a'), isTrue);
    expect(await holdings.recordMfOrder(order(1000), claimKey: 'a'), isFalse);
    expect(
      await holdings.recordMfOrder(order(1000 + 86400000 * 31), claimKey: 'b'),
      isTrue,
    );
    final orders = await holdings.watchMfOrders().first;
    expect(orders, hasLength(2));
    expect(orders.first.at, greaterThan(orders.last.at));
    expect(orders.first.amountMinor, 500000);
  });
}

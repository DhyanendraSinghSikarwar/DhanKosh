// Per-account low-balance alert (FR-13-23).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  final today = DateTime.utc(2026, 11, 6);
  const low = LowBalanceInput(
    id: 4,
    label: 'HDFC Bank ••1234',
    balanceMinor: 80000,
    thresholdMinor: 100000,
  );

  test('alerts once a day while below the threshold', () {
    final d = AlertRules.lowBalanceAccountAlerts(
      accounts: [low],
      today: today,
      alerted: {},
    );
    expect(d, hasLength(1));
    expect(d.single.title, 'HDFC Bank ••1234 balance is low');
    expect(d.single.link, 'hisaab://account/4');
    expect(d.single.kind, AlertKind.lowBalanceAccount);
    expect(
      AlertRules.lowBalanceAccountAlerts(
        accounts: [low],
        today: today,
        alerted: {d.single.key},
      ),
      isEmpty,
    );
    expect(
      AlertRules.lowBalanceAccountAlerts(
        accounts: [low],
        today: today.add(const Duration(days: 1)),
        alerted: {d.single.key},
      ),
      hasLength(1),
    );
  });

  test('at or above the threshold is quiet', () {
    const ok = LowBalanceInput(
      id: 4,
      label: 'x',
      balanceMinor: 100000,
      thresholdMinor: 100000,
    );
    expect(
      AlertRules.lowBalanceAccountAlerts(
        accounts: [ok],
        today: today,
        alerted: {},
      ),
      isEmpty,
    );
  });

  test('the threshold is saved on the account and can be cleared', () async {
    final env = TestEnv();
    addTearDown(env.close);
    await env.ingest(parsed(amountMinor: 1000, ref: 'a'));
    final id = (await env.accounts.watchVisible().first).single.id;
    await env.accounts.setLowBalance(id, 250000);
    expect((await env.accounts.byId(id))!.lowBalanceMinor, 250000);
    await env.accounts.setLowBalance(id, null);
    expect((await env.accounts.byId(id))!.lowBalanceMinor, isNull);
  });
}

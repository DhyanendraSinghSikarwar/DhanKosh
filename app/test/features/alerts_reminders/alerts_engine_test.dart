import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/activity_log/domain/activity_logger.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_poster_impl.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_state_stores_impl.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alerts_engine.dart';
import 'package:hisaab/features/expense_tracking/data/budget_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/data/recurring_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

class FakePoster implements AlertPoster {
  bool enabled = true;
  bool accept = true;
  final posted = <AlertDecision>[];
  final cancelled = <int>[];

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<bool> post(AlertDecision decision) async {
    if (!accept) return false;
    posted.add(decision);
    return true;
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<String?> takeLaunchRoute() async => null;
}

class FakeActivity implements ActivityLogger {
  final entries = <ActivityEntry>[];

  /// Alert log notes, e.g. `sent:budget`, `log:budgetWarning`.
  List<String> get notes => [for (final e in entries) e.note ?? ''];

  @override
  Future<void> record(ActivityEntry entry) async => entries.add(entry);
}

class FakeSettings implements AlertSettingsRepository {
  AlertSettings value = const AlertSettings();

  @override
  Future<AlertSettings> read() async => value;

  @override
  Stream<AlertSettings> watch() => Stream.value(value);

  @override
  Future<void> setBudgetAlertPercent(int percent) async =>
      value = AlertSettings(budgetAlertPercent: percent);

  @override
  Future<void> setCardDueReminders({required bool value}) async {}

  @override
  Future<void> setTransactionNotifications({required bool value}) async {}

  @override
  Future<void> setWeeklySummary({required bool value}) async =>
      this.value = AlertSettings(weeklySummary: value);

  @override
  Future<void> setUpdateAvailable({required bool value}) async {}
}

void main() {
  late TestEnv env;
  late FakePoster poster;
  late FakeSettings settings;
  late AlertedKeyStoreImpl keys;
  late BudgetRepositoryImpl budgets;
  late RecurringRepositoryImpl recurring;
  late AlertsEngine engine;
  late FakeActivity activity;

  setUp(() {
    env = TestEnv();
    poster = FakePoster();
    settings = FakeSettings();
    activity = FakeActivity();
    keys = AlertedKeyStoreImpl(env.db);
    budgets = BudgetRepositoryImpl(env.db);
    recurring = RecurringRepositoryImpl(env.db);
    engine = AlertsEngine(
      budgets: budgets,
      recurring: recurring,
      accounts: env.accounts,
      alerted: keys,
      poster: poster,
      settings: settings,
      activity: activity,
      nowMs: () => t0,
    );
  });

  tearDown(() => env.close());

  Future<void> spendAgainstBudget(int spentMinor, {int limit = 10000}) async {
    await budgets.save(Category.food, limit);
    await env.ingest(parsed(amountMinor: spentMinor));
  }

  test('budget alert fires once per key (FR-21-05, FR-21-14)', () async {
    await spendAgainstBudget(25000);
    expect(await engine.run(), 1);
    expect(poster.posted.single.title, 'Food & Dining: budget used up');
    expect(await keys.all(), {poster.posted.single.key});
    expect(activity.notes, ['sent:budget']);
    expect(await engine.run(), 0);
    expect(poster.posted, hasLength(1));
    expect(activity.entries, hasLength(1));
  });

  test('failed post does not store the key (FR-21-14)', () async {
    await spendAgainstBudget(25000);
    poster.accept = false;
    expect(await engine.run(), 0);
    expect(await keys.all(), isEmpty);
    poster.accept = true;
    expect(await engine.run(), 1);
    expect(await keys.all(), hasLength(1));
  });

  test('notifications off posts nothing and stores nothing (FR-21-16)',
      () async {
    await spendAgainstBudget(25000);
    poster.enabled = false;
    expect(await engine.run(), 0);
    expect(poster.posted, isEmpty);
    expect(await keys.all(), isEmpty);
    expect(activity.entries, isEmpty);
  });

  test('FR-21-27 budget at the user percent only logs; used up notifies',
      () async {
    await spendAgainstBudget(9500);
    // Level 90 reached: informational, nothing posted, one log entry.
    expect(await engine.run(), 0);
    expect(poster.posted, isEmpty);
    expect(activity.notes, ['log:budgetWarning']);
    expect(activity.entries.single.source, ActivitySource.alerts);
    expect(await keys.all(), hasLength(1));
    // Once only.
    expect(await engine.run(), 0);
    expect(activity.entries, hasLength(1));
    // Used up: a real notification, also logged.
    await env.ingest(parsed(amountMinor: 1000, ref: 'second'));
    expect(await engine.run(), 1);
    expect(poster.posted.single.title, 'Food & Dining: budget used up');
    expect(activity.notes, ['log:budgetWarning', 'sent:budget']);
  });

  test('FR-21-27 informational events still log with notifications blocked',
      () async {
    await spendAgainstBudget(9500);
    poster.enabled = false;
    expect(await engine.run(), 0);
    expect(poster.posted, isEmpty);
    expect(activity.notes, ['log:budgetWarning']);
  });

  test('budget percent setting is honoured (FR-21-18)', () async {
    await spendAgainstBudget(8500);
    settings.value = const AlertSettings(budgetAlertPercent: 95);
    expect(await engine.run(), 0);
    settings.value = const AlertSettings(budgetAlertPercent: 80);
    // 80% is informational: nothing posted, one log entry.
    expect(await engine.run(), 0);
    expect(poster.posted, isEmpty);
    expect(activity.notes, ['log:budgetWarning']);
  });

  test('low-balance bill due tomorrow alerts once (FR-21-06)', () async {
    await env.ingest(parsed(balance: 100000));
    final acc = (await env.accounts.watchVisible().first).single;
    await recurring.add(
      RecurringDraft(
        name: 'Rent',
        amountMinor: 500000,
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 26,
        category: Category.food,
        accountId: acc.id,
      ),
    );
    expect(await engine.run(), 1);
    expect(poster.posted.single.key, 'bill:Rent:2026-09-26');
    expect(poster.posted.single.title, startsWith('Rent'));
    expect(await engine.run(), 0);
  });

  test('concurrent runs do not double-send (FR-21-19)', () async {
    await spendAgainstBudget(25000);
    final results = await Future.wait([engine.run(), engine.run()]);
    expect(results.fold<int>(0, (a, b) => a + b), 1);
  });

  test('cancel decisions reach the poster', () async {
    await poster.cancel(30001);
    expect(poster.cancelled, [30001]);
  });

  test('links map to routes (FR-21-15)', () {
    expect(alertRouteFor('hisaab://transaction/7'), '/transaction/7');
    expect(alertRouteFor('hisaab://budgets'), '/budgets');
    expect(alertRouteFor('hisaab://account/3'), '/accounts/3');
    expect(alertRouteFor('junk'), '/home');
    expect(AlertPosterImpl.channelIdFor(AlertKind.budget), 'budget');
    expect(AlertPosterImpl.channelIdFor(AlertKind.cardBill), 'cards');
    expect(AlertPosterImpl.channelIdFor(AlertKind.newTransaction), 'info');
  });

  test('FR-31-34 update notification once per version, toggle respected',
      () async {
    var known = '0.3.0';
    AlertsEngine make() => AlertsEngine(
          budgets: budgets,
          recurring: recurring,
          accounts: env.accounts,
          alerted: keys,
          poster: poster,
          settings: settings,
          updateVersion: () async => known,
          installedVersion: '0.2.0',
          nowMs: () => t0,
        );
    final e = make();
    expect(await e.run(), 1);
    expect(poster.posted.single.title, 'DhanKosh 0.3.0 is available');
    expect(await e.run(), 0);
    known = '0.4.0';
    expect(await e.run(), 1);
    known = '0.5.0';
    settings.value = const AlertSettings(updateAvailable: false);
    expect(await e.run(), 0);
    expect(poster.posted, hasLength(2));
  });
}

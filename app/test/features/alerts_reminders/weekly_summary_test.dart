import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_state_stores_impl.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/alerts_reminders/domain/alerts_engine.dart';
import 'package:hisaab/features/expense_tracking/data/budget_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/data/recurring_repository_impl.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

class _Poster implements AlertPoster {
  final posted = <AlertDecision>[];
  @override
  Future<bool> areEnabled() async => true;
  @override
  Future<bool> post(AlertDecision d) async {
    posted.add(d);
    return true;
  }

  @override
  Future<void> cancel(int id) async {}
  @override
  Future<String?> takeLaunchRoute() async => null;
}

class _Settings implements AlertSettingsRepository {
  _Settings(this.value);
  AlertSettings value;
  @override
  Future<AlertSettings> read() async => value;
  @override
  Stream<AlertSettings> watch() => Stream.value(value);
  @override
  Future<void> setBudgetAlertPercent(int percent) async {}
  @override
  Future<void> setCardDueReminders({required bool value}) async {}
  @override
  Future<void> setTransactionNotifications({required bool value}) async {}
  @override
  Future<void> setWeeklySummary({required bool value}) async {}
  @override
  Future<void> setUpdateAvailable({required bool value}) async {}
}

void main() {
  // Friday 2026-09-25: last completed week is Mon 14 to Sun 20 Sep.
  final friday = DateTime.utc(2026, 9, 25);
  const on = AlertSettings(weeklySummary: true);

  group('AlertRules.weeklySummary (FR-21-21)', () {
    test('week starts on the Monday before last', () {
      expect(AlertRules.lastWeekStart(friday), DateTime.utc(2026, 9, 14));
      // A Monday reports the week that just ended.
      expect(
        AlertRules.lastWeekStart(DateTime.utc(2026, 9, 21)),
        DateTime.utc(2026, 9, 14),
      );
      expect(
        AlertRules.lastWeekStart(DateTime.utc(2026, 9, 27)),
        DateTime.utc(2026, 9, 14),
      );
    });

    test('text: total, comparison, top category', () {
      final d = AlertRules.weeklySummary(
        today: friday,
        week: const WeekSpend(
          spentMinor: 420000,
          topCategory: Category.food,
          topCategoryMinor: 180000,
        ),
        previous: const WeekSpend(spentMinor: 530000),
        settings: on,
        alerted: const {},
      )!;
      expect(d.kind, AlertKind.weeklySummary);
      expect(d.key, 'weekly:2026-09-14');
      expect(d.title, 'Week 14-20 Sep: ₹4,200 spent');
      expect(
          d.body,
          '₹1,100 less than the week before. Top: Food & Dining '
          '₹1,800.');
    });

    test('more, same and no previous week', () {
      String body(int w, int p) => AlertRules.weeklySummary(
            today: friday,
            week: WeekSpend(spentMinor: w),
            previous: WeekSpend(spentMinor: p),
            settings: on,
            alerted: const {},
          )!
              .body;
      expect(body(20000, 10000), '₹100 more than the week before.');
      expect(body(20000, 20000), 'Same as the week before.');
      expect(body(20000, 0), 'Nothing was spent the week before.');
    });

    test('off by default, once per week, silent when nothing spent', () {
      WeekSpend w(int v) => WeekSpend(spentMinor: v);
      expect(
        AlertRules.weeklySummary(
          today: friday,
          week: w(100),
          previous: w(100),
          settings: const AlertSettings(),
          alerted: const {},
        ),
        isNull,
      );
      expect(
        AlertRules.weeklySummary(
          today: friday,
          week: w(100),
          previous: w(100),
          settings: on,
          alerted: const {'weekly:2026-09-14'},
        ),
        isNull,
      );
      expect(
        AlertRules.weeklySummary(
          today: friday,
          week: w(0),
          previous: w(0),
          settings: on,
          alerted: const {},
        ),
        isNull,
      );
    });

    test('a month-spanning week is labelled with both months', () {
      final d = AlertRules.weeklySummary(
        today: DateTime.utc(2026, 10, 7),
        week: const WeekSpend(spentMinor: 100),
        previous: const WeekSpend(spentMinor: 100),
        settings: on,
        alerted: const {},
      )!;
      expect(d.title, startsWith('Week 28 Sep-4 Oct'));
    });
  });

  group('engine (FR-21-21)', () {
    late TestEnv env;
    late _Poster poster;
    late AlertedKeyStoreImpl keys;
    late AlertsEngine engine;
    late _Settings settings;

    setUp(() async {
      env = TestEnv();
      poster = _Poster();
      keys = AlertedKeyStoreImpl(env.db);
      settings = _Settings(on);
      engine = AlertsEngine(
        budgets: BudgetRepositoryImpl(env.db),
        recurring: RecurringRepositoryImpl(env.db),
        accounts: env.accounts,
        alerted: keys,
        poster: poster,
        settings: settings,
        txs: env.txs,
        nowMs: () => t0,
      );
      int at(int d, int h) => Ist.startMs(2026, 9, d) + h * hour;
      await env.ingest(
        parsed(amountMinor: 300000, time: at(15, 10), ref: 'a'),
      );
      await env.ingest(
        parsed(
          amountMinor: 120000,
          time: at(17, 11),
          ref: 'b',
          merchant: 'Big Bazaar',
          category: Category.groceries,
        ),
      );
      await env.ingest(
        parsed(amountMinor: 530000, time: at(9, 10), ref: 'c'),
      );
      // This (incomplete) week must not count.
      await env.ingest(
        parsed(amountMinor: 999900, time: at(23, 10), ref: 'd'),
      );
    });
    tearDown(() => env.close());

    test('posts once with the right totals', () async {
      expect(await engine.run(), 1);
      final d = poster.posted.single;
      expect(d.title, 'Week 14-20 Sep: ₹4,200 spent');
      expect(d.body, contains('₹1,100 less'));
      expect(d.body, contains('Top: Food & Dining ₹3,000'));
      expect(await keys.all(), {'weekly:2026-09-14'});
      expect(await engine.run(), 0);
    });

    test('toggle off posts nothing', () async {
      settings.value = const AlertSettings();
      expect(await engine.run(), 0);
    });
  });
}

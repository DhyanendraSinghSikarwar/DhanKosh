import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/activity_log/data/activity_log_repository_impl.dart';
import 'package:hisaab/features/activity_log/domain/activity_stats.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/activity_log/presentation/activity_log_screen.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

DateTime _t(int d, int h, [int m = 0]) => DateTime(2026, 10, d, h, m);
final DateTime _now = _t(21, 12);

ActivityEntry _e(
  ActivitySource s,
  DateTime at, {
  int read = 0,
  int relevant = 0,
  int added = 0,
  int emails = 0,
  int statements = 0,
  String? error,
  String? note,
}) =>
    ActivityEntry(
      at: at,
      source: s,
      read: read,
      relevant: relevant,
      added: added,
      emails: emails,
      statements: statements,
      error: error,
      note: note,
    );

void main() {
  late TestEnv env;
  late ActivityLogRepositoryImpl repo;
  setUp(() {
    env = TestEnv();
    repo = ActivityLogRepositoryImpl(env.db);
  });
  tearDown(() => env.close());

  test('keeps newest 200, newest first, clear empties (TC-22-01)', () async {
    for (var i = 0; i < 205; i++) {
      await repo.record(
        _e(
          ActivitySource.smsScan,
          DateTime(2026, 1, 1).add(Duration(hours: i)),
        ),
      );
    }
    final l = await repo.watch().first;
    expect(l, hasLength(200));
    expect(l.first.at.isAfter(l.last.at), isTrue);
    await repo.clear();
    expect(await repo.watch().first, isEmpty);
  });

  test('coalesces live sources within 30 min (TC-22-02)', () async {
    await repo.record(
      _e(ActivitySource.notifications, _t(21, 10), read: 1, added: 1),
    );
    await repo.record(
      _e(
        ActivitySource.notifications,
        _t(21, 10, 20),
        read: 1,
        note: 'no amount',
      ),
    );
    var l = await repo.watch().first;
    expect(l, hasLength(1));
    expect(l.single.read, 2);
    expect(l.single.runs, 2);
    expect(l.single.note, 'no amount');
    expect(l.single.at, _t(21, 10));
    await repo.record(_e(ActivitySource.notifications, _t(21, 10, 55)));
    expect(await repo.watch().first, hasLength(2));
    await repo.record(_e(ActivitySource.smsScan, _t(21, 11)));
    await repo.record(_e(ActivitySource.smsScan, _t(21, 11, 5)));
    await repo.record(_e(ActivitySource.smsLive, _t(21, 11, 6)));
    l = await repo.watch().first;
    expect(l, hasLength(5));
  });

  test('totals, week start and last sync times (TC-22-03, TC-22-04)', () {
    final list = [
      _e(ActivitySource.smsScan, _t(21, 9), read: 100, added: 5),
      _e(ActivitySource.smsLive, _t(21, 8), read: 2, added: 1),
      _e(
        ActivitySource.imap,
        _t(21, 7),
        emails: 10,
        added: 2,
        statements: 1,
      ),
      _e(ActivitySource.smsScan, _t(20, 9), read: 50, added: 9),
      _e(ActivitySource.smsScan, _t(18, 9), read: 7, added: 3),
    ];
    final today = ActivityStats.today(list, _now);
    expect(
      [today.sms, today.emails, today.added, today.statements],
      [102, 10, 8, 1],
    );
    // 21 Oct 2026 is a Wednesday: week starts Mon 19 Oct.
    expect(ActivityStats.weekStart(_now), DateTime(2026, 10, 19));
    expect(ActivityStats.week(list, _now).sms, 152);
    final errored = [
      _e(ActivitySource.smsScan, _t(21, 10), error: 'permission'),
      ...list,
    ];
    expect(ActivityStats.lastSms(errored), _t(21, 9));
    expect(ActivityStats.lastEmail(errored), _t(21, 7));
    expect(ActivityStats.lastSms(const []), isNull);
  });

  test('row subtitles match the worked examples (TC-22-05, TC-22-06)', () {
    final scan = ActivityEntry(
      at: _now,
      source: ActivitySource.smsScan,
      read: 412,
      relevant: 63,
      added: 9,
      merged: 2,
      review: 1,
      skipped: 4,
    );
    expect(
      ActivityStats.subtitle(scan),
      '412 SMS, 63 from banks · 9 added · 2 merged · 1 to review · '
      '4 duplicates',
    );
    final live = ActivityEntry(
      at: _now,
      source: ActivitySource.smsLive,
      read: 3,
      relevant: 3,
      added: 2,
      runs: 3,
    );
    expect(ActivityStats.title(live), 'Live SMS · ×3');
    expect(ActivityStats.subtitle(live), '3 SMS · 2 added');
    final imap = _e(
      ActivitySource.imap,
      _now,
      emails: 18,
      added: 5,
      statements: 2,
    );
    expect(ActivityStats.subtitle(imap), '18 emails · 5 added · 2 statements');
    expect(
      ActivityStats.subtitle(
        _e(ActivitySource.notifications, _now, read: 1, note: 'no amount'),
      ),
      '1 notifications · 0 added · Skipped: no amount',
    );
    expect(
      ActivityStats.subtitle(
        _e(ActivitySource.smsScan, _now, error: 'permission'),
      ),
      'Failed: permission',
    );
    expect(ActivityStats.matches(imap, ActivitySource.statements), isTrue);
    expect(ActivityStats.matches(imap, ActivitySource.smsScan), isFalse);
  });

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(env.settings),
          activityLogRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(home: ActivityLogScreen(now: () => _now)),
      ),
    );
    await settle(t);
  }

  testWidgets('empty state, then rows, filter and clear (TC-22-10/11)',
      (t) async {
    await pump(t);
    expect(find.text('No activity yet'), findsOneWidget);
    expect(find.byKey(const Key('activity-clear')), findsNothing);

    await t.runAsync(() async {
      await repo.record(
        _e(ActivitySource.smsScan, _t(21, 9), read: 5, relevant: 5, added: 1),
      );
      await repo.record(
        _e(ActivitySource.smsScan, _t(20, 9), error: 'permission'),
      );
      await repo.record(_e(ActivitySource.imap, _t(9, 9), emails: 3));
    });
    await settle(t);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Fri, 9 Oct 2026'), findsOneWidget);
    expect(find.text('Failed: permission'), findsOneWidget);

    await t.tap(find.byKey(const Key('pill-IMAP')));
    await t.pump();
    expect(find.text('Failed: permission'), findsNothing);
    expect(find.text('3 emails · 0 added'), findsOneWidget);
    await t.tap(find.byKey(const Key('pill-IMAP')));
    await t.pump();
    expect(find.text('Failed: permission'), findsOneWidget);

    await t.tap(find.byKey(const Key('activity-clear')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Cancel'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Failed: permission'), findsOneWidget);
    await t.tap(find.byKey(const Key('activity-clear')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const Key('activity-clear-confirm')));
    await settle(t);
    expect(find.text('No activity yet'), findsOneWidget);
    await teardownApp(t);
  });
}

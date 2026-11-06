import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/notification_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/notification_ingestion/data/notification_settings_store.dart';
import 'package:hisaab/features/notification_ingestion/data/watched_apps_store.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/handle_app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/notification_engine.dart';
import 'package:hisaab/features/notification_ingestion/presentation/notification_access_card.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';

import '../../support/test_env.dart';
import 'notification_engine_test.dart';

void main() {
  late TestEnv env;
  late FakeNotificationSource source;

  Future<void> pump(
    WidgetTester t, {
    bool access = false,
    NotificationHealth health = const NotificationHealth(),
  }) async {
    env = TestEnv();
    source = FakeNotificationSource()
      ..access = access
      ..healthNow = health;
    final store =
        NotificationSettingsStore(SettingsKeyValueStore(env.settings));
    final watched = WatchedAppsStore(SettingsKeyValueStore(env.settings));
    final engine = NotificationEngine(
      source: source,
      settings: store,
      watched: watched,
      handle: HandleAppNotification(
        settings: store,
        watched: watched,
        ingest: IngestMessage(ledger: env.txs),
      ),
    );
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 2000);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(env.settings),
          notificationEngineProvider.overrideWithValue(engine),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: NotificationAccessCard()),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
  }

  Future<void> tap(WidgetTester t, Key k) async {
    await t.runAsync(() async {
      await t.tap(find.byKey(k));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pump();
  }

  tearDown(() => env.close());

  testWidgets('off by default with warning and watched apps (FR-04-16)',
      (t) async {
    await pump(t);
    expect(find.text('Off'), findsOneWidget);
    expect(find.byKey(const Key('notif-off-warning')), findsOneWidget);
    // The app list moved to its own screen (FR-04-19, FR-04-20); the card
    // links to it and says how many apps are built in.
    expect(find.byKey(const Key('notif-apps')), findsOneWidget);
    expect(find.text('Watched apps'), findsOneWidget);
    expect(
      find.textContaining('${PaymentApps.all.length} payment and bank apps'),
      findsOneWidget,
    );
  });

  testWidgets('enabling without access opens settings (FR-04-16)', (t) async {
    await pump(t);
    await tap(t, const Key('notif-enabled'));
    expect(find.text('Needs access'), findsOneWidget);
    expect(source.opened, 1);
    expect(source.enabled, isTrue);
    expect(find.byKey(const Key('notif-open-settings')), findsOneWidget);
    expect(find.byKey(const Key('notif-restricted-hint')), findsOneWidget);
    await tap(t, const Key('notif-open-settings'));
    expect(source.opened, 2);
  });

  testWidgets('enabled with access shows On (FR-04-16)', (t) async {
    await pump(t, access: true);
    await tap(t, const Key('notif-enabled'));
    expect(find.text('On'), findsOneWidget);
    expect(source.opened, 0);
    expect(find.byKey(const Key('notif-open-settings')), findsNothing);
  });

  testWidgets(
      'says it is waiting while Android has not bound the listener '
      '(FR-04-22)', (t) async {
    await pump(t, access: true);
    expect(find.byKey(const Key('notif-health')), findsNothing);
    await tap(t, const Key('notif-enabled'));
    expect(find.textContaining('Waiting for Android'), findsOneWidget);
  });

  testWidgets('shows when the last payment notification was read (FR-04-22)',
      (t) async {
    await pump(
      t,
      access: true,
      health: NotificationHealth(
        connectedAt: 2000,
        lastReadAt: DateTime.now()
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
        readCount: 3,
        queued: 2,
      ),
    );
    await tap(t, const Key('notif-enabled'));
    expect(find.textContaining('5 min ago'), findsOneWidget);
    expect(find.textContaining('2 waiting'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/notification_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/notification_ingestion/data/notification_settings_store.dart';
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

  Future<void> pump(WidgetTester t, {bool access = false}) async {
    env = TestEnv();
    source = FakeNotificationSource()..access = access;
    final store =
        NotificationSettingsStore(SettingsKeyValueStore(env.settings));
    final engine = NotificationEngine(
      source: source,
      settings: store,
      handle: HandleAppNotification(
        settings: store,
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
    expect(find.text('PhonePe'), findsOneWidget);
    expect(find.text('WhatsApp Pay'), findsOneWidget);
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
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/notification_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/notification_ingestion/data/notification_settings_store.dart';
import 'package:hisaab/features/notification_ingestion/data/watched_apps_store.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/handle_app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/notification_engine.dart';
import 'package:hisaab/features/notification_ingestion/presentation/watched_apps_screen.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';

import '../../support/test_env.dart';

/// Only the pieces the screen uses (FR-04-19, FR-04-20).
class _Source implements NotificationSource {
  List<UnwatchedApp> seen = const [];
  List<String>? packages;

  @override
  Stream<AppNotification> get live => const Stream.empty();
  @override
  Future<List<AppNotification>> drainPending() async => const [];
  @override
  Future<bool> hasAccess() async => true;
  @override
  Future<int> sdkInt() async => 34;
  @override
  Future<void> openAccessSettings() async {}
  @override
  Future<void> configure({
    required bool enabled,
    required List<String> packages,
  }) async =>
      this.packages = packages;
  @override
  Future<NotificationHealth> health() async => const NotificationHealth();
  @override
  Future<List<UnwatchedApp>> seenApps() async => seen;
  @override
  Future<void> forgetSeen() async {}
}

void main() {
  late TestEnv env;
  late _Source source;
  late WatchedAppsStore watched;

  Future<void> pump(
    WidgetTester t, {
    List<UnwatchedApp> seen = const [],
    Map<String, String> added = const {},
  }) async {
    env = TestEnv();
    source = _Source()..seen = seen;
    final store =
        NotificationSettingsStore(SettingsKeyValueStore(env.settings));
    watched = WatchedAppsStore(SettingsKeyValueStore(env.settings));
    for (final e in added.entries) {
      await watched.addExtra(e.key, e.value);
    }
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
    t.view.physicalSize = const Size(800, 4000);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(env.db),
          notificationEngineProvider.overrideWithValue(engine),
        ],
        child: const MaterialApp(home: WatchedAppsScreen()),
      ),
    );
    await t.pumpAndSettle();
  }

  tearDown(() => env.close());

  testWidgets('lists the built-in apps and switches one off (FR-04-19)',
      (t) async {
    await pump(t);
    expect(find.text('PhonePe'), findsOneWidget);
    expect(find.text('slice'), findsOneWidget);

    final phonepe = find.byKey(const Key('watched-builtin-com.phonepe.app'));
    expect(t.widget<SwitchListTile>(phonepe).value, isTrue);
    await t.tap(phonepe);
    await t.pumpAndSettle();

    expect(t.widget<SwitchListTile>(phonepe).value, isFalse);
    expect((await watched.load()).disabled, contains('com.phonepe.app'));
    expect(source.packages, isNot(contains('com.phonepe.app')));
  });

  testWidgets('with nothing seen the list says so (FR-04-20)', (t) async {
    await pump(t);
    expect(find.textContaining('Nothing yet'), findsOneWidget);
  });

  testWidgets('a seen app can be added and is then read (FR-04-20)', (t) async {
    await pump(
      t,
      seen: const [
        UnwatchedApp(
          packageName: 'com.example.newpay',
          label: 'NewPay',
          count: 2,
        ),
      ],
    );
    expect(find.textContaining('Nothing yet'), findsNothing);
    expect(
      find.byKey(const Key('watched-seen-com.example.newpay')),
      findsOneWidget,
    );

    await t.tap(find.widgetWithText(TextButton, 'Watch'));
    await t.pumpAndSettle();

    expect((await watched.load()).extra['com.example.newpay'], 'NewPay');
    expect(source.packages, contains('com.example.newpay'));
    expect(
      find.byKey(const Key('watched-extra-com.example.newpay')),
      findsOneWidget,
    );
  });

  testWidgets('an added app shows under "Apps you added" (FR-04-20)',
      (t) async {
    await pump(t, added: const {'com.example.newpay': 'NewPay'});

    expect(
      find.byKey(const Key('watched-extra-com.example.newpay')),
      findsOneWidget,
    );
    expect(find.text('com.example.newpay'), findsOneWidget);
    expect(
      PaymentApps.effectivePackages(await watched.load()),
      contains('com.example.newpay'),
    );
  });
}

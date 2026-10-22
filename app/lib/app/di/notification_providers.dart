import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/core/platform_channels/notifications_channel.dart';
import 'package:hisaab/features/notification_ingestion/data/notification_settings_store.dart';
import 'package:hisaab/features/notification_ingestion/data/notification_source_impl.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/handle_app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/notification_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_providers.g.dart';

// Phase 2 wiring: payment-app notifications -> parser_core -> ledger (F-04).

/// Native `notifications` channel.
@Riverpod(keepAlive: true)
NotificationsChannel notificationsChannel(Ref ref) =>
    const NotificationsChannel();

/// Native listener bridge.
@Riverpod(keepAlive: true)
NotificationSource notificationSource(Ref ref) => NotificationSourceImpl(
      ref.watch(notificationsChannelProvider),
      lockSkipper: ref.watch(lockSkipperProvider),
    );

/// Persisted `app_notifications` switch.
@Riverpod(keepAlive: true)
NotificationSettingsRepository notificationSettings(Ref ref) =>
    NotificationSettingsStore(ref.watch(keyValueStoreProvider));

/// Live notification lifecycle.
@Riverpod(keepAlive: true)
NotificationEngine notificationEngine(Ref ref) {
  final engine = NotificationEngine(
    source: ref.watch(notificationSourceProvider),
    settings: ref.watch(notificationSettingsProvider),
    handle: HandleAppNotification(
      settings: ref.watch(notificationSettingsProvider),
      ingest: ref.watch(ingestMessageProvider),
    ),
    activity: ref.watch(activityLoggerProvider),
  );
  ref.onDispose(engine.stop);
  return engine;
}

/// Starts or drains the notification engine; call at launch and on resume
/// (FR-04-02, FR-04-16). Never throws.
@Riverpod(keepAlive: true)
Future<void> Function() notificationSync(Ref ref) => () async {
      try {
        final engine = ref.read(notificationEngineProvider);
        if (engine.running) {
          await engine.drain();
        } else {
          await engine.start();
        }
      } on Object {
        // Native side missing (tests, desktop).
      }
    };

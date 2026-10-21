import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';

/// Native notification listener bridge.
abstract interface class NotificationSource {
  /// Notifications arriving while the engine runs.
  Stream<AppNotification> get live;

  /// Notifications queued natively while Dart was away; clears the queue.
  Future<List<AppNotification>> drainPending();

  /// Whether system notification access is granted.
  Future<bool> hasAccess();

  /// Android API level; 0 when unknown.
  Future<int> sdkInt();

  /// Opens system notification-listener settings.
  Future<void> openAccessSettings();

  /// Pushes the in-app switch and package allow-list to native.
  Future<void> configure({
    required bool enabled,
    required List<String> packages,
  });
}

/// Persistence for the `app_notifications` switch (default off).
abstract interface class NotificationSettingsRepository {
  /// Whether payment-app notifications are read.
  Future<bool> isEnabled();

  /// Turns reading on or off.
  Future<void> setEnabled({required bool enabled});
}

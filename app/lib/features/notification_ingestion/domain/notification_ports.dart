import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';

/// An app that posted notifications while it was not watched (FR-04-20).
class UnwatchedApp {
  /// Creates an [UnwatchedApp].
  const UnwatchedApp({
    required this.packageName,
    required this.label,
    this.lastSeen = 0,
    this.count = 0,
  });

  /// Android package.
  final String packageName;

  /// The app's name as the phone shows it; the package when unknown.
  final String label;

  /// Latest post time, epoch ms.
  final int lastSeen;

  /// How many notifications it posted.
  final int count;
}

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

  /// Apps that posted notifications but are not watched (FR-04-20).
  Future<List<UnwatchedApp>> seenApps();

  /// Clears the seen-apps list (FR-04-20).
  Future<void> forgetSeen();
}

/// Persistence for the user's own watched-app choices (FR-04-19, FR-04-20).
abstract interface class WatchedAppsRepository {
  /// Built-ins switched off and apps added by the user.
  Future<WatchedApps> load();

  /// Switches a built-in app on or off.
  Future<void> setBuiltIn(String packageName, {required bool watched});

  /// Starts reading [packageName], shown and parsed as [label].
  Future<void> addExtra(String packageName, String label);

  /// Stops reading an added app.
  Future<void> removeExtra(String packageName);
}

/// Persistence for the `app_notifications` switch (default off).
abstract interface class NotificationSettingsRepository {
  /// Whether payment-app notifications are read.
  Future<bool> isEnabled();

  /// Turns reading on or off.
  Future<void> setEnabled({required bool enabled});
}

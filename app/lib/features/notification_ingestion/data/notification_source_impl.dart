import 'package:hisaab/core/platform_channels/notifications_channel.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/shared/ports/lock_skipper.dart';

AppNotification _toDomain(RawNotification r) => AppNotification(
      packageName: r.packageName,
      key: r.key,
      postTime: r.postTime,
      parts: r.parts,
      isGroupSummary: r.isGroupSummary,
      isOngoing: r.isOngoing,
      category: r.category,
      hasMessagesExtra: r.hasMessagesExtra,
      channelId: r.channelId,
    );

/// [NotificationSource] over the `notifications` channel (FR-04-01).
class NotificationSourceImpl implements NotificationSource {
  /// Creates the source.
  const NotificationSourceImpl(
    this._channel, {
    this.lockSkipper = const NoLockSkipper(),
  });

  final NotificationsChannel _channel;

  /// Skips the app lock before the listener settings open (FR-25-06).
  final LockSkipper lockSkipper;

  @override
  Stream<AppNotification> get live =>
      _channel.liveNotifications().map(_toDomain);

  @override
  Future<List<AppNotification>> drainPending() async => [
        for (final r in await _channel.drainPending()) _toDomain(r),
      ];

  @override
  Future<bool> hasAccess() => _channel.isAccessEnabled();

  @override
  Future<int> sdkInt() => _channel.sdkInt();

  @override
  Future<void> openAccessSettings() {
    lockSkipper.skipNextLock();
    return _channel.openAccessSettings();
  }

  @override
  Future<void> configure({
    required bool enabled,
    required List<String> packages,
  }) =>
      _channel.configure(enabled: enabled, packages: packages);
}

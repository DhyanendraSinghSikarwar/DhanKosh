import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// One notification as returned by the native listener (FR-04-04).
class RawNotification {
  /// Creates a [RawNotification].
  const RawNotification({
    required this.packageName,
    required this.key,
    required this.postTime,
    required this.parts,
    this.isGroupSummary = false,
    this.isOngoing = false,
    this.category,
    this.hasMessagesExtra = false,
    this.channelId,
  });

  /// Parses a native map.
  factory RawNotification.fromMap(Map<Object?, Object?> m) => RawNotification(
        packageName: (m['packageName'] ?? '').toString(),
        key: (m['key'] ?? '').toString(),
        postTime: (m['postTime'] as num?)?.toInt() ?? 0,
        parts: [
          for (final e in (m['parts'] as List<Object?>? ?? const []))
            e.toString(),
        ],
        isGroupSummary: m['isGroupSummary'] as bool? ?? false,
        isOngoing: m['isOngoing'] as bool? ?? false,
        category: m['category'] as String?,
        hasMessagesExtra: m['hasMessagesExtra'] as bool? ?? false,
        channelId: m['channelId'] as String?,
      );

  /// Posting app package.
  final String packageName;

  /// `StatusBarNotification.key`.
  final String key;

  /// Post time, epoch ms.
  final int postTime;

  /// Trimmed, distinct, non-empty text parts in extraction order.
  final List<String> parts;

  /// `FLAG_GROUP_SUMMARY`.
  final bool isGroupSummary;

  /// `FLAG_ONGOING_EVENT`.
  final bool isOngoing;

  /// `Notification.category`.
  final String? category;

  /// Whether `EXTRA_MESSAGES` was present.
  final bool hasMessagesExtra;

  /// Notification channel id (API 26+).
  final String? channelId;
}

/// Typed wrapper for the `notifications` platform channel (+ live events).
class NotificationsChannel extends ChannelBase {
  /// Creates the wrapper over the `notifications` channel.
  const NotificationsChannel() : super(_channel);

  static const MethodChannel _channel =
      MethodChannel(ChannelNames.notifications);
  static const EventChannel _live =
      EventChannel(ChannelNames.notificationsLive);

  /// Whether the user granted notification-listener access (FR-04-16).
  Future<bool> isAccessEnabled() async =>
      (await invoke<bool>('isAccessEnabled')) ?? false;

  /// Android API level; 0 when unknown.
  Future<int> sdkInt() async => (await invoke<int>('sdkInt')) ?? 0;

  /// Opens the system notification-listener settings (FR-04-16).
  Future<void> openAccessSettings() => invoke<void>('openAccessSettings');

  /// Returns and clears notifications queued while Dart was not listening.
  Future<List<RawNotification>> drainPending() async {
    final list = await invoke<List<Object?>>('drainPending');
    return [
      for (final e in list ?? const <Object?>[])
        RawNotification.fromMap(e! as Map<Object?, Object?>),
    ];
  }

  /// Pushes the in-app switch and package allow-list the listener filters
  /// with (FR-04-01, FR-04-02). Until called, the listener reads nothing.
  Future<void> configure({
    required bool enabled,
    required List<String> packages,
  }) =>
      invoke<void>('configure', {'enabled': enabled, 'packages': packages});

  /// Notifications while the engine is running.
  Stream<RawNotification> liveNotifications() =>
      _live.receiveBroadcastStream().map(
            (e) => RawNotification.fromMap(e! as Map<Object?, Object?>),
          );
}

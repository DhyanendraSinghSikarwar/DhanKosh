import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Typed wrapper for the `alerts` platform channel (memory 21).
class AlertsChannel extends ChannelBase {
  /// Creates the wrapper.
  const AlertsChannel() : super(_channel);

  static const MethodChannel _channel = MethodChannel(ChannelNames.alerts);

  /// Posts a notification; creates the native channel on demand. Returns
  /// false when notifications are not allowed. [channelId] is one of
  /// `budget`, `bills`, `cards`, `info`; [route] is opened on tap; each of
  /// [actions] (`label`, `route`) is a button that opens its route.
  Future<bool> post({
    required int id,
    required String channelId,
    required String title,
    required String body,
    String? route,
    List<Map<String, String>> actions = const [],
    int? timeoutMs,
  }) async =>
      (await invoke<bool>('post', {
        'id': id,
        'channelId': channelId,
        'title': title,
        'body': body,
        'route': route,
        'actions': actions,
        'timeoutMs': timeoutMs,
      })) ??
      false;

  /// Cancels notification [id].
  Future<void> cancel(int id) => invoke<void>('cancel', {'id': id});

  /// Whether the OS lets the app post notifications.
  Future<bool> areEnabled() async =>
      (await invoke<bool>('areEnabled')) ?? false;

  /// Route of the tapped alert that launched the app; cleared once read.
  Future<String?> takeLaunchRoute() => invoke<String>('takeLaunchRoute');

  /// Path of a PDF, CSV or XLSX another app shared with or opened in
  /// DhanKosh, already copied to the cache; cleared once read (FR-05-26).
  Future<String?> takeSharedFile() => invoke<String>('takeSharedFile');

  /// Blocks or allows screenshots and the recents preview (FLAG_SECURE,
  /// FR-25-23). True when an activity applied it now.
  Future<bool> setSecure({required bool on}) async =>
      (await invoke<bool>('setSecure', {'on': on})) ?? false;
}

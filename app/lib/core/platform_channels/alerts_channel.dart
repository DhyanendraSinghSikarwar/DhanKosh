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
  /// `budget`, `bills`, `cards`, `info`; [route] is opened on tap.
  Future<bool> post({
    required int id,
    required String channelId,
    required String title,
    required String body,
    String? route,
  }) async =>
      (await invoke<bool>('post', {
        'id': id,
        'channelId': channelId,
        'title': title,
        'body': body,
        'route': route,
      })) ??
      false;

  /// Cancels notification [id].
  Future<void> cancel(int id) => invoke<void>('cancel', {'id': id});

  /// Whether the OS lets the app post notifications.
  Future<bool> areEnabled() async =>
      (await invoke<bool>('areEnabled')) ?? false;

  /// Route of the tapped alert that launched the app; cleared once read.
  Future<String?> takeLaunchRoute() => invoke<String>('takeLaunchRoute');
}

import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Native SMS permission snapshot.
class NativeSmsStatus {
  /// Creates a [NativeSmsStatus].
  const NativeSmsStatus({required this.granted, required this.rationale});

  /// READ_SMS and RECEIVE_SMS both granted.
  final bool granted;

  /// `shouldShowRequestPermissionRationale(READ_SMS)`.
  final bool rationale;
}

/// Typed wrapper for the `permissions` platform channel.
class PermissionsChannel extends ChannelBase {
  /// Creates the wrapper over the `permissions` channel.
  const PermissionsChannel() : super(_channel);

  static const MethodChannel _channel = MethodChannel(
    ChannelNames.permissions,
  );

  /// Real SMS permission state (never trust the dialog result).
  Future<NativeSmsStatus> smsStatus() async {
    final m = await invoke<Map<Object?, Object?>>('smsStatus');
    return NativeSmsStatus(
      granted: m?['granted'] as bool? ?? false,
      rationale: m?['rationale'] as bool? ?? false,
    );
  }

  /// Shows the READ_SMS + RECEIVE_SMS dialog; completes when it closes.
  Future<void> requestSms() => invoke<void>('requestSms');

  /// Asks POST_NOTIFICATIONS on Android 13+; false when not applicable.
  Future<bool> requestNotifications() async =>
      (await invoke<bool>('requestNotifications')) ?? false;

  /// Opens App info for this package.
  Future<void> openAppSettings() => invoke<void>('openAppSettings');
}

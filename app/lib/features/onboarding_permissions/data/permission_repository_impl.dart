import 'package:hisaab/core/platform_channels/permissions_channel.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/sms_permission_state.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';

/// [SmsPermissionRepository] over the native `permissions` channel.
class SmsPermissionRepositoryImpl implements SmsPermissionRepository {
  /// Creates the repository.
  SmsPermissionRepositoryImpl(
    this._channel, {
    this.beforeOpenSettings,
  });

  final PermissionsChannel _channel;

  /// Hook to skip the next app lock before App info opens (FR-01-15).
  final Future<void> Function()? beforeOpenSettings;

  bool _blocked = false;

  @override
  Future<SmsPermissionState> read() async {
    final s = await _channel.smsStatus();
    if (s.granted) _blocked = false;
    return SmsPermissionState(granted: s.granted, blocked: _blocked);
  }

  @override
  Future<SmsPermissionState> request() async {
    if (_blocked) {
      await openAppSettings();
      return await read();
    }
    await _channel.requestSms();
    final s = await _channel.smsStatus();
    // Trust the real state; infer "blocked" only from a refusal without rationale.
    _blocked = !s.granted && !s.rationale;
    return SmsPermissionState(granted: s.granted, blocked: _blocked);
  }

  @override
  Future<void> openAppSettings() async {
    await beforeOpenSettings?.call();
    await _channel.openAppSettings();
  }
}

/// [NotificationPermission] over the native `permissions` channel.
class NotificationPermissionImpl implements NotificationPermission {
  /// Creates the requester.
  const NotificationPermissionImpl(this._channel);

  final PermissionsChannel _channel;

  @override
  Future<void> request() async {
    await _channel.requestNotifications();
  }
}

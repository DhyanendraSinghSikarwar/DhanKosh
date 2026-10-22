import 'package:hisaab/core/platform_channels/permissions_channel.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/sms_permission_state.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/shared/ports/lock_skipper.dart';

/// [SmsPermissionRepository] over the native `permissions` channel.
class SmsPermissionRepositoryImpl implements SmsPermissionRepository {
  /// Creates the repository.
  SmsPermissionRepositoryImpl(
    this._channel, {
    this.beforeOpenSettings,
    this.lockSkipper = const NoLockSkipper(),
  });

  /// Skips the app lock around system UI (FR-01-15, FR-25-06).
  final LockSkipper lockSkipper;

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
    lockSkipper.skipNextLock();
    await _channel.requestSms();
    final s = await _channel.smsStatus();
    // Trust the real state; infer "blocked" only from a refusal without rationale.
    _blocked = !s.granted && !s.rationale;
    return SmsPermissionState(granted: s.granted, blocked: _blocked);
  }

  @override
  Future<void> openAppSettings() async {
    lockSkipper.skipNextLock();
    await beforeOpenSettings?.call();
    await _channel.openAppSettings();
  }
}

/// [NotificationPermission] over the native `permissions` channel.
class NotificationPermissionImpl implements NotificationPermission {
  /// Creates the requester.
  const NotificationPermissionImpl(
    this._channel, {
    this.lockSkipper = const NoLockSkipper(),
  });

  final PermissionsChannel _channel;

  /// Skips the app lock around the dialog.
  final LockSkipper lockSkipper;

  @override
  Future<void> request() async {
    lockSkipper.skipNextLock();
    await _channel.requestNotifications();
  }
}

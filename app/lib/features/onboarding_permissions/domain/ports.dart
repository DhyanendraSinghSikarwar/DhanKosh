import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/sms_permission_state.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';

/// Keystore-backed string store (e.g. flutter_secure_storage).
abstract interface class SecureStore {
  /// Value for [key], or null.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);
}

/// Sealed identity persistence.
abstract interface class IdentityRepository {
  /// Saved identity, or null.
  Future<Identity?> read();

  /// Saves the identity.
  Future<void> save(Identity identity);
}

/// Plain profile persistence (settings store).
abstract interface class ProfileRepository {
  /// Saved profile.
  Future<UserProfile> read();

  /// Saves the profile; this write ends the onboarding gate.
  Future<void> save(UserProfile profile);
}

/// SMS permission access.
abstract interface class SmsPermissionRepository {
  /// Real permission state; `blocked` is remembered after a refused request.
  Future<SmsPermissionState> read();

  /// Asks, or opens App settings when blocked (FR-01-10).
  Future<SmsPermissionState> request();

  /// Opens App info for the package.
  Future<void> openAppSettings();
}

/// POST_NOTIFICATIONS request.
abstract interface class NotificationPermission {
  /// Launches the Android 13+ dialog; the result is ignored.
  Future<void> request();
}

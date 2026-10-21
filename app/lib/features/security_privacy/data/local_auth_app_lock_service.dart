import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:local_auth/local_auth.dart';

/// [AppLockService] over `local_auth` (FR-25-02, FR-25-03).
class LocalAuthAppLockService implements AppLockService {
  /// Creates the service.
  LocalAuthAppLockService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<AuthAvailability> availability() async {
    try {
      if (await _auth.isDeviceSupported()) return AuthAvailability.available;
      return AuthAvailability.noneEnrolled;
    } on Object {
      return AuthAvailability.unavailable;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Your transactions are protected',
      );
    } on Object {
      return false;
    }
  }
}

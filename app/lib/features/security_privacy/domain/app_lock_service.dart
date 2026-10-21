/// Whether the phone can authenticate (FR-25-02).
enum AuthAvailability {
  /// Biometric or device credential ready.
  available,

  /// No screen lock set.
  noneEnrolled,

  /// Hardware or platform missing.
  unsupported,

  /// Check failed.
  unavailable,
}

/// Port over the system authentication prompt.
abstract interface class AppLockService {
  /// Current availability.
  Future<AuthAvailability> availability();

  /// Shows the system prompt (biometric weak or device credential, no own
  /// PIN). False on cancel or failure; never throws.
  Future<bool> authenticate();
}

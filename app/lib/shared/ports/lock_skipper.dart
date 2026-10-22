/// Arms a one-shot skip of the app lock before a deliberate hop to a system
/// UI (permission dialog, settings, file picker; FR-25-06). Implemented in
/// `app/di` over the lock controller so features never import security.
abstract interface class LockSkipper {
  /// Skips the lock for the next background transition.
  void skipNextLock();
}

/// No-op skipper for tests and callers without a lock.
class NoLockSkipper implements LockSkipper {
  /// Creates the no-op skipper.
  const NoLockSkipper();

  @override
  void skipNextLock() {}
}

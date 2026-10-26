/// Blocks screenshots and the recents preview (FR-25-23).
abstract interface class ScreenGuard {
  /// Applies the choice to the app window; never throws.
  Future<void> setBlocked({required bool blocked});
}

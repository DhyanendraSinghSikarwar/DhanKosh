import 'package:hisaab/features/news_support_updates/domain/release.dart';

/// Update check state (FR-31-19). Download states are deferred; installs
/// hand the release URL to the system.
sealed class UpdateState {
  const UpdateState();
}

/// Nothing checked yet.
class UpdateIdle extends UpdateState {
  /// Creates the state.
  const UpdateIdle();
}

/// Check in flight.
class UpdateChecking extends UpdateState {
  /// Creates the state.
  const UpdateChecking();
}

/// Installed version is current.
class UpdateUpToDate extends UpdateState {
  /// Creates the state.
  const UpdateUpToDate();
}

/// A newer [release] exists.
class UpdateAvailable extends UpdateState {
  /// Creates the state.
  const UpdateAvailable(this.release);

  /// The newer release.
  final Release release;
}

/// Check failed with [message].
class UpdateFailed extends UpdateState {
  /// Creates the state.
  const UpdateFailed(this.message);

  /// User-visible text.
  final String message;
}

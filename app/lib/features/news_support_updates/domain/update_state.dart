import 'package:hisaab/features/news_support_updates/domain/release.dart';

/// Update check and install state (FR-31-19).
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

/// Check or install failed with [message]; [release] allows a retry.
class UpdateFailed extends UpdateState {
  /// Creates the state.
  const UpdateFailed(this.message, {this.release});

  /// User-visible text.
  final String message;

  /// The release that failed to install, if any.
  final Release? release;
}

/// [release] is downloading; [progress] runs 0..1, 1 means verifying.
class UpdateDownloading extends UpdateState {
  /// Creates the state.
  const UpdateDownloading(this.release, this.progress);

  /// The release being downloaded.
  final Release release;

  /// Fraction done.
  final double progress;
}

/// The installer is blocked until "Install unknown apps" is allowed.
class UpdatePermissionNeeded extends UpdateState {
  /// Creates the state.
  const UpdatePermissionNeeded(this.release);

  /// The release waiting to install.
  final Release release;
}

/// The verified APK was handed to the system installer.
class UpdateHandedOff extends UpdateState {
  /// Creates the state.
  const UpdateHandedOff(this.release);

  /// The release handed over.
  final Release release;
}

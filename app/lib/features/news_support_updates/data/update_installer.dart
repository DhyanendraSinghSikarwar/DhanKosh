import 'package:hisaab/features/news_support_updates/data/apk_downloader.dart';
import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_policy.dart';
import 'package:hisaab/features/news_support_updates/domain/update_ports.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';

/// Download, verify and hand off one release (FR-31-20..22). Returns the
/// final [UpdateState]; never throws.
class UpdateInstaller {
  /// Creates the installer for the [installed] version.
  UpdateInstaller({
    required ApkDownloader downloader,
    required ApkInstaller installer,
    required this.installed,
  })  : _downloader = downloader,
        _installer = installer;

  final ApkDownloader _downloader;
  final ApkInstaller _installer;

  /// Installed version; equal or older releases are refused.
  final String installed;

  /// Runs the flow for [release]. [onProgress] gets 0..1 (1 = verifying).
  Future<UpdateState> run(
    Release release, {
    void Function(double progress)? onProgress,
    UpdateCancel? cancel,
  }) async {
    if (!mayInstall(candidate: release.version, installed: installed)) {
      return UpdateFailed(
        'DhanKosh ${release.version} is not newer than the version '
        'installed, so it was not installed.',
        release: release,
      );
    }
    try {
      final file = await _downloader.download(
        release,
        onProgress: onProgress,
        cancel: cancel,
      );
      final handoff = await _installer.install(file.path);
      // The file is kept: the installer reads it after this call. Stale
      // files are removed on the next start (ApkDownloader.cleanStale).
      return switch (handoff) {
        InstallHandoff.started => UpdateHandedOff(release),
        InstallHandoff.permissionNeeded => UpdatePermissionNeeded(release),
      };
    } on UpdateCancelled {
      return UpdateAvailable(release);
    } on UpdateFailure catch (e) {
      return UpdateFailed(e.message, release: release);
    } on Object {
      return UpdateFailed(
        'The update could not be installed.',
        release: release,
      );
    }
  }

  /// Removes stale downloads.
  Future<void> cleanStale() => _downloader.cleanStale(installed);
}

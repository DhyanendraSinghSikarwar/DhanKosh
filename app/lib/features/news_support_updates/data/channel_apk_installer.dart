import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/core/platform_channels/widget_channel.dart';
import 'package:hisaab/features/news_support_updates/domain/update_ports.dart';
import 'package:hisaab/shared/ports/lock_skipper.dart';

/// [ApkInstaller] over the native `widget` channel (FR-31-22). Arms the
/// app-lock skip first so returning from the installer or the settings page
/// does not lock the app (FR-25-06).
class ChannelApkInstaller implements ApkInstaller {
  /// Creates the installer.
  const ChannelApkInstaller(this._channel, this._lock);

  final WidgetChannel _channel;
  final LockSkipper _lock;

  @override
  Future<InstallHandoff> install(String path) async {
    _lock.skipNextLock();
    try {
      final r = await _channel.installApk(path);
      return r == 'permission_needed'
          ? InstallHandoff.permissionNeeded
          : InstallHandoff.started;
    } on ChannelFailure {
      throw const UpdateFailure(
        "The installer couldn't be opened. Use Open release page instead.",
      );
    }
  }
}

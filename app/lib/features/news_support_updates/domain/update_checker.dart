import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';
import 'package:hisaab/features/news_support_updates/domain/version_compare.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// Epoch ms of the last successful check (FR-31-18).
const lastUpdateCheckKey = SettingKey<int>('last_update_check', 0);

/// One day, ms.
const updateCheckInterval = 86400000;

/// Whether a check should run now (FR-31-18). [force] is a manual check.
bool updateCheckDue({
  required bool enabled,
  required int lastCheckMs,
  required int nowMs,
  bool force = false,
}) =>
    force || (enabled && nowMs - lastCheckMs >= updateCheckInterval);

/// Latest release lookup. Returns null when none exists (404); throws on
/// any other failure.
abstract interface class ReleaseSource {
  /// Fetches the latest release.
  Future<Release?> latest();
}

/// Daily-throttled update check (FR-31-15, FR-31-18).
class UpdateChecker {
  /// Creates the checker.
  UpdateChecker({
    required ReleaseSource source,
    required SettingsRepository settings,
    required String currentVersion,
    DateTime Function()? clock,
  })  : _source = source,
        _settings = settings,
        _current = currentVersion,
        _clock = clock ?? DateTime.now;

  final ReleaseSource _source;
  final SettingsRepository _settings;
  final String _current;
  final DateTime Function() _clock;

  /// Runs the check; null when skipped by the gate. Never throws.
  Future<UpdateState?> check({bool force = false}) async {
    final now = _clock().millisecondsSinceEpoch;
    try {
      final due = updateCheckDue(
        enabled: await _settings.read(SettingKeys.checkUpdates),
        lastCheckMs: await _settings.read(lastUpdateCheckKey),
        nowMs: now,
        force: force,
      );
      if (!due) return null;
      final release = await _source.latest();
      await _settings.write(lastUpdateCheckKey, now);
      if (release != null && isNewer(release.version, _current)) {
        return UpdateAvailable(release);
      }
      return const UpdateUpToDate();
    } on Object catch (e) {
      final why = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : 'no connection';
      return UpdateFailed("Couldn't check for updates: $why");
    }
  }
}

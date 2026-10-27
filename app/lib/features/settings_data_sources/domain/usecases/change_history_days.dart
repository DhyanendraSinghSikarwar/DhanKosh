import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// Re-reads data sources over the saved window (FR-26-30). Implemented in
/// `app/di` over SMS and email.
abstract interface class HistoryReread {
  /// Forgets every source's read position so the whole window is read again.
  Future<void> resetPositions();

  /// Starts the catch-up scans; must not throw.
  Future<void> start();
}

/// Sets "History to read" (7 to 365 days). Raising it re-reads the longer
/// period; lowering it only shortens the next first read (FR-26-30).
/// Re-reading is idempotent because ingest de-duplicates.
class ChangeHistoryDays {
  /// Creates the use case.
  const ChangeHistoryDays(this._settings, this._reread);

  final SettingsRepository _settings;
  final HistoryReread _reread;

  /// Shortest and longest window.
  static const min = 7;
  static const max = 365;

  /// Quick picks shown in the UI.
  static const presets = [7, 30, 90, 180, 365];

  /// Saves [days] (clamped); returns true when a re-read was started.
  Future<bool> call(int days) async {
    final next = days.clamp(min, max);
    final old = await _settings.read(SettingKeys.historyDays);
    if (next == old) return false;
    await _settings.write(SettingKeys.historyDays, next);
    if (next < old) return false;
    await _reread.resetPositions();
    await _reread.start();
    return true;
  }
}

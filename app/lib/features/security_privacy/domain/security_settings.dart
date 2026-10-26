import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// Security settings (F-25). Plain preferences only, never secrets.
abstract final class SecuritySettings {
  /// Minutes away before the app locks again (FR-25-21). 0 = immediately.
  static const autoLockMinutes = SettingKey<int>('auto_lock_minutes', 0);

  /// Block screenshots and the recents preview (FR-25-23).
  static const blockScreenshots = SettingKey<bool>('block_screenshots', false);

  /// Allowed timeout choices in minutes (FR-25-21).
  static const timeoutChoices = [0, 1, 5, 15];

  /// Label of a timeout choice.
  static String timeoutLabel(int minutes) =>
      minutes <= 0 ? 'Immediately' : '$minutes min';
}

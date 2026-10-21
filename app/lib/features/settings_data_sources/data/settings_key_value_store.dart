import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';

/// [KeyValueStore] over [SettingsRepository]; an empty string reads as null.
class SettingsKeyValueStore implements KeyValueStore {
  /// Creates the store.
  const SettingsKeyValueStore(this._settings);

  final SettingsRepository _settings;

  @override
  Future<String?> getString(String key) async {
    final v = await _settings.read(SettingKey<String>(key, ''));
    return v.isEmpty ? null : v;
  }

  @override
  Future<void> setString(String key, String value) =>
      _settings.write(SettingKey<String>(key, ''), value);
}

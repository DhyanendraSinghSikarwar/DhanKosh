import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// Key-value settings store (FR-26-12): streams, defaults before load.
abstract interface class SettingsRepository {
  Future<T> read<T>(SettingKey<T> key);
  Stream<T> watch<T>(SettingKey<T> key);

  /// Writes through [SettingKey.normalize] when set.
  Future<void> write<T>(SettingKey<T> key, T value);

  /// Back to the default (also resets a monotonic key).
  Future<void> remove<T>(SettingKey<T> key);

  /// Appends [entry] to a string list capped to the newest [cap] (FR-26-13).
  Future<void> appendCapped(String name, String entry, {int cap = 300});
  Future<List<String>> readList(String name);
}

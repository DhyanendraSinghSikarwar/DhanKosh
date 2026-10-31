import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// In-memory settings for widget tests that must not open the database
/// (the Book persists through the settings store, FR-26-31).
class FakeSettings implements SettingsRepository {
  final Map<String, Object?> _m = {};

  @override
  Future<T> read<T>(SettingKey<T> key) async =>
      _m.containsKey(key.name) ? _m[key.name]! as T : key.defaultValue;

  @override
  Stream<T> watch<T>(SettingKey<T> key) => Stream.fromFuture(read(key));

  @override
  Future<void> write<T>(SettingKey<T> key, T value) async =>
      _m[key.name] = value;

  @override
  Future<void> remove<T>(SettingKey<T> key) async => _m.remove(key.name);

  @override
  Future<void> appendCapped(String name, String entry, {int cap = 300}) async {}

  @override
  Future<List<String>> readList(String name) async => const [];
}

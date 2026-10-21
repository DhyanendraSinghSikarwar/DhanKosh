import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// [SettingsRepository] over the `settings` table (FR-26-12..14).
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._db);

  final AppDatabase _db;

  static String _encode<T>(T v) => switch (v) {
        final Set<String> s => jsonEncode(s.toList()),
        _ => '$v',
      };

  static T _decode<T>(SettingKey<T> key, String? raw) {
    if (raw == null) return key.defaultValue;
    final d = key.defaultValue;
    try {
      final out = switch (d) {
        bool() => raw == 'true',
        int() => int.parse(raw),
        Set<String>() => (jsonDecode(raw) as List).cast<String>().toSet(),
        _ => raw,
      };
      return out as T;
    } on FormatException {
      return d;
    }
  }

  Selectable<SettingRow> _row(String name) =>
      _db.select(_db.settings)..where((t) => t.key.equals(name));

  @override
  Future<T> read<T>(SettingKey<T> key) async {
    final row = await _row(key.name).getSingleOrNull();
    final value = _decode(key, row?.value);
    return value;
  }

  @override
  Stream<T> watch<T>(SettingKey<T> key) => _row(key.name)
      .watchSingleOrNull()
      .map((r) => _decode(key, r?.value))
      .distinct();

  @override
  Future<void> write<T>(SettingKey<T> key, T value) async {
    final n = key.normalize;
    final v = n == null ? value : n(await read(key), value);
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: key.name, value: _encode(v)),
        );
  }

  @override
  Future<void> remove<T>(SettingKey<T> key) =>
      (_db.delete(_db.settings)..where((t) => t.key.equals(key.name))).go();

  @override
  Future<List<String>> readList(String name) async {
    final raw = (await _row(name).getSingleOrNull())?.value;
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  @override
  Future<void> appendCapped(String name, String entry, {int cap = 300}) async {
    final list = [...await readList(name), entry];
    final capped = list.length > cap ? list.sublist(list.length - cap) : list;
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: name, value: jsonEncode(capped)),
        );
  }
}

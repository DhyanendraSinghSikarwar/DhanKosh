import 'dart:convert';

import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';
import 'package:hisaab/features/statement_import/domain/column_layout_store.dart';
import 'package:parser_core/parser_core.dart';

/// [ColumnLayoutStore] over a [KeyValueStore]. One JSON object under
/// `stmt_layouts`, newest 40 layouts kept (FR-05-28).
class ColumnLayoutStoreImpl implements ColumnLayoutStore {
  /// Creates the store.
  const ColumnLayoutStoreImpl(this._kv);

  final KeyValueStore _kv;

  static const _key = 'stmt_layouts';
  static const _keep = 40;

  Future<Map<String, Object?>> _read() async {
    final raw = await _kv.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final v = jsonDecode(raw);
      return v is Map<String, Object?> ? v : {};
    } on FormatException {
      return {};
    }
  }

  @override
  Future<ColumnMapping?> find(String signature) async {
    final v = (await _read())[signature];
    return v is Map<String, Object?> ? ColumnMapping.fromJson(v) : null;
  }

  @override
  Future<void> save(String signature, ColumnMapping mapping) async {
    final all = await _read();
    // Re-inserting moves it to the end, which is "newest".
    all
      ..remove(signature)
      ..[signature] = mapping.toJson();
    while (all.length > _keep) {
      all.remove(all.keys.first);
    }
    await _kv.setString(_key, jsonEncode(all));
  }

  @override
  Future<void> clear() => _kv.setString(_key, '');
}

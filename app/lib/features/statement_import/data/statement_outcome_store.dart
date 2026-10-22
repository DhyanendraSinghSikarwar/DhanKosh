import 'dart:convert';

import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';
import 'package:hisaab/features/statement_import/domain/statement_outcome.dart';

/// [StatementOutcomeStore] over the settings key-value store (FR-05-20).
class StatementOutcomeKvStore implements StatementOutcomeStore {
  /// Creates the store.
  const StatementOutcomeKvStore(this._kv);

  final KeyValueStore _kv;

  static String _key(int id) => 'stmt_outcome_$id';

  @override
  Future<void> save(int id, StatementOutcome o) =>
      _kv.setString(_key(id), jsonEncode(o.toJson()));

  @override
  Future<StatementOutcome?> read(int id) async {
    final raw = await _kv.getString(_key(id));
    if (raw == null || raw.isEmpty) return null;
    try {
      return StatementOutcome.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> delete(int id) => _kv.setString(_key(id), '');
}

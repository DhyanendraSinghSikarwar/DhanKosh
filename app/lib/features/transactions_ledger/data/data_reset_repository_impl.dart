import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/settings_data_sources/domain/data_reset_repository.dart';

/// [DataResetRepository] kept with the ledger data layer so every write to
/// `transactions` stays in one place (FR-08-17).
class DataResetRepositoryImpl implements DataResetRepository {
  /// Creates the repository.
  const DataResetRepositoryImpl(this._db);

  final AppDatabase _db;

  static const _cursorKeys = ['sms_cursor', 'last_sms_scan', 'last_sms_result'];

  @override
  Future<void> clearLedger() => _db.transaction(() async {
        final byName = {for (final t in _db.allTables) t.actualTableName: t};
        for (final name in [
          'transaction_sources',
          'deleted_messages',
          'transactions',
          'accounts',
          'merchant_rules',
          'custom_subcategories',
          'custom_categories',
        ]) {
          await _db.customUpdate(
            'DELETE FROM $name',
            updates: {byName[name]!},
            updateKind: UpdateKind.delete,
          );
        }
        await _db.customUpdate(
          'DELETE FROM settings WHERE key IN (?, ?, ?)',
          variables: [for (final k in _cursorKeys) Variable<String>(k)],
          updates: {byName['settings']!},
          updateKind: UpdateKind.delete,
        );
      });
}

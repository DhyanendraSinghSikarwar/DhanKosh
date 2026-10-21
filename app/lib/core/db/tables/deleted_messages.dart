import 'package:drift/drift.dart';

/// Tombstones so a deleted message is never re-ingested (FR-08-22).
@DataClassName('DeletedMessageRow')
class DeletedMessages extends Table {
  TextColumn get source => text()();
  TextColumn get messageId => text()();
  IntColumn get deletedAt => integer()();

  @override
  Set<Column> get primaryKey => {source, messageId};
}

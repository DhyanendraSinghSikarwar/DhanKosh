import 'package:drift/drift.dart';
import 'package:hisaab/core/db/tables/transactions.dart';

/// The messages behind a ledger row (FR-08, FR-07). Doubles as the processed-id
/// set: unique (source, source_message_id) makes ingest idempotent.
@DataClassName('TransactionSourceRow')
@TableIndex(name: 'index_tx_sources_transaction', columns: {#transactionId})
@TableIndex(name: 'index_tx_sources_parsed_hash', columns: {#parsedHash})
class TransactionSources extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(
        Transactions,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get source => text()();
  TextColumn get sourceMessageId => text()();
  TextColumn get sender => text()();
  TextColumn get parsedHash => text()();
  TextColumn get rawText => text().nullable()();
  IntColumn get receivedAt => integer()();
  TextColumn get subject => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {source, sourceMessageId},
      ];
}

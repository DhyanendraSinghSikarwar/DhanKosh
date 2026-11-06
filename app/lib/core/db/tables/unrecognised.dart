import 'package:drift/drift.dart';

/// Messages no parser could read, waiting for the user (F-38, FR-38-04).
///
/// The text is kept only while it is useful: a waiting row for 30 days, a
/// handled row for 30 days (so a dismissal can be undone). After that `body`
/// is emptied and the row stays as a tombstone keyed by `body_hash`, so the
/// same text does not come back.
@DataClassName('UnrecognisedRow')
class UnrecognisedMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `SMS` or `APP`.
  TextColumn get source => text()();

  /// SMS header or the app's display name.
  TextColumn get sender => text()();

  /// Normalised sender, see `SenderKey`.
  TextColumn get senderKey => text()();

  /// Id of the message in its source, so adding it books it once.
  TextColumn get sourceMessageId => text()();

  /// SHA-256 of the text; with `sender_key` it identifies "the same message".
  TextColumn get bodyHash => text()();
  TextColumn get body => text()();
  IntColumn get receivedAt => integer()();

  /// `FRESH`, `ADDED`, `DISMISSED`, `IGNORED` or `EXPIRED`.
  TextColumn get status => text()();

  /// The transaction it became, when `ADDED`. Soft reference.
  IntColumn get transactionId => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get handledAt => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {senderKey, bodyHash},
      ];
}

/// Senders the user taught the app, or switched off (F-38, FR-38-07/08).
@DataClassName('SenderPrefRow')
class SenderPrefs extends Table {
  TextColumn get senderKey => text()();

  /// `LEARNED` or `IGNORED`.
  TextColumn get state => text()();

  /// Bank, last four digits and currency of the account last used.
  TextColumn get bankName => text().nullable()();
  TextColumn get last4 => text().nullable()();
  TextColumn get currency => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {senderKey};
}

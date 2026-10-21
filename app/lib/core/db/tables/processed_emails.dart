import 'package:drift/drift.dart';

/// Emails already handled, so a re-read never repeats work (FR-03-10,
/// FR-03-14). Ids look like `imap:<Message-ID>`.
@DataClassName('ProcessedEmailRow')
class ProcessedEmails extends Table {
  TextColumn get messageId => text()();

  /// Epoch ms.
  IntColumn get processedAt => integer()();

  /// `PARSED`, `REJECTED` or `SKIPPED`.
  TextColumn get outcome => text()();

  IntColumn get transactionId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {messageId};
}

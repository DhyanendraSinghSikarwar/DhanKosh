import 'package:drift/drift.dart';

/// Imported statement files (FR-05-01, FR-05-08). Card dues and overrides live
/// in their own tables (memory 14 section 9), so `kind` is never CARD_*.
@DataClassName('StatementRow')
class Statements extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `file:<sha>` or `<msgId>#pdf<i>`.
  TextColumn get key => text().unique()();

  /// `EMAIL`, `FILE`, `SMS` or `MANUAL`.
  TextColumn get source => text()();
  TextColumn get sender => text()();
  TextColumn get subject => text().nullable()();
  TextColumn get fileName => text()();
  IntColumn get receivedAt => integer()();

  /// `PARSED`, `LOCKED`, `EMPTY` or `UNREADABLE`.
  TextColumn get status => text()();
  IntColumn get transactionCount => integer().withDefault(const Constant(0))();
  IntColumn get holdingCount => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()();
  TextColumn get bankName => text().nullable()();
  TextColumn get last4 => text().nullable()();
  IntColumn get processedAt => integer()();

  /// `CREDIT_CARD`, `BANK`, `INVESTMENT`, `OTHER` or `PROTECTED`.
  TextColumn get kind => text().nullable()();
  IntColumn get totalDueMinor => integer().nullable()();
  IntColumn get minDueMinor => integer().nullable()();
  IntColumn get dueEpochDay => integer().nullable()();
  IntColumn get creditLimitMinor => integer().nullable()();
  IntColumn get statementEpochDay => integer().nullable()();
  IntColumn get openingMinor => integer().nullable()();
  IntColumn get closingMinor => integer().nullable()();
  IntColumn get debitsMinor => integer().nullable()();
  IntColumn get creditsMinor => integer().nullable()();
  IntColumn get availableMinor => integer().nullable()();
  TextColumn get emailText => text().nullable()();
}

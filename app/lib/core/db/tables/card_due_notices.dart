import 'package:drift/drift.dart';

/// Card bill and payment notices from SMS, email and statements (FR-14-06).
@DataClassName('CardDueNoticeRow')
class CardDueNotices extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `carddue:<bank>:<last4|any+total>:<day>` or
  /// `cardpay:<bank>:<last4>:<day>:<amount>`.
  TextColumn get key => text().unique()();

  /// `DUE` or `PAYMENT`.
  TextColumn get kind => text()();

  /// `SMS`, `EMAIL` or `STATEMENT`.
  TextColumn get source => text()();
  TextColumn get bankName => text().nullable()();
  TextColumn get last4 => text().nullable()();
  IntColumn get totalDueMinor => integer().nullable()();
  IntColumn get minDueMinor => integer().nullable()();
  IntColumn get dueEpochDay => integer().nullable()();
  IntColumn get creditLimitMinor => integer().nullable()();
  IntColumn get statementEpochDay => integer().nullable()();
  IntColumn get availableMinor => integer().nullable()();
  IntColumn get paymentMinor => integer().nullable()();
  IntColumn get receivedAt => integer()();
  IntColumn get processedAt => integer()();
}

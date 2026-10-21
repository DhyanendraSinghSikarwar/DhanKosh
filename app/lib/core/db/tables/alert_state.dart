import 'package:drift/drift.dart';

/// Sent-alert dedupe keys, newest 300 kept (FR-21-14).
@DataClassName('AlertedKeyRow')
class AlertedKeys extends Table {
  TextColumn get key => text()();
  IntColumn get sentAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Per card and due date reminder state (FR-21-11).
@DataClassName('CardDueReminderRow')
class CardDueReminderState extends Table {
  IntColumn get cardId => integer()();
  IntColumn get dueEpochDay => integer()();

  /// CSV of stage names.
  TextColumn get stagesSent => text().withDefault(const Constant(''))();
  BoolColumn get paid => boolean().withDefault(const Constant(false))();
  IntColumn get snoozedUntilEpochDay => integer().nullable()();

  @override
  Set<Column> get primaryKey => {cardId, dueEpochDay};
}

/// IST day of the last balance-updated notice per account (FR-21-04).
@DataClassName('BalanceNoticeDayRow')
class BalanceNoticeDays extends Table {
  TextColumn get accountKey => text()();
  IntColumn get lastEpochDay => integer()();

  @override
  Set<Column> get primaryKey => {accountKey};
}

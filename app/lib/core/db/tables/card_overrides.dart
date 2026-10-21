import 'package:drift/drift.dart';

/// Manual card figures (FR-14-07). One row per card.
@DataClassName('CardOverrideRow')
class CardOverrides extends Table {
  /// `<bank lower>:<last4>`.
  TextColumn get cardKey => text()();
  IntColumn get billedMinor => integer().nullable()();
  IntColumn get minDueMinor => integer().nullable()();
  IntColumn get dueEpochDay => integer().nullable()();
  IntColumn get unbilledMinor => integer().nullable()();
  IntColumn get outstandingMinor => integer().nullable()();

  /// Epoch ms the user saved the override.
  IntColumn get setAt => integer()();

  @override
  Set<Column> get primaryKey => {cardKey};
}

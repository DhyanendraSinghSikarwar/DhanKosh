import 'package:drift/drift.dart';

/// User-added recurring items (FR-12-03). Room table name `recurring`.
@DataClassName('RecurringRow')
class RecurringItems extends Table {
  @override
  String get tableName => 'recurring';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get amountMinor => integer()();
  BoolColumn get income => boolean()();

  /// `MONTHLY` or `YEARLY`.
  TextColumn get frequency => text()();

  /// 1..31.
  IntColumn get dayOfMonth => integer()();

  /// 1..12 for yearly.
  IntColumn get month => integer().nullable()();
  TextColumn get category => text()();

  /// Soft reference to `accounts.id`, no FK.
  IntColumn get accountId => integer().nullable()();
  IntColumn get createdAt => integer()();
}

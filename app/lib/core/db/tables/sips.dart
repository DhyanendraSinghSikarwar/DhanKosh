import 'package:drift/drift.dart';

/// User-added SIPs (FR-12-17). Tracking only, no money moves.
@DataClassName('SipRow')
class Sips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get amountMinor => integer()();

  /// `DAILY`, `WEEKLY` or `MONTHLY`.
  TextColumn get frequency => text()();

  /// 1..31 for monthly.
  IntColumn get dayOfMonth => integer().nullable()();

  /// 1 (Monday) .. 7 (Sunday) for weekly.
  IntColumn get weekday => integer().nullable()();

  /// Epoch day (IST) of the first instalment.
  IntColumn get startDay => integer()();
  IntColumn get createdAt => integer()();
}

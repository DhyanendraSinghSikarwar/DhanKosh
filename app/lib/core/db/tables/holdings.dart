import 'package:drift/drift.dart';

/// Investment holdings (FR-16-09). One row per investment.
@DataClassName('HoldingRow')
class Holdings extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `EPF`, `MUTUAL_FUND`, `STOCK`, `ETF`, `NPS`, `PPF`, `BOND`, `GOLD`, `FD`
  /// or `OTHER`.
  TextColumn get kind => text()();
  TextColumn get name => text()();

  /// ISIN, `EPF:<member>`, `NPS:<last4>[:T2]`, `MF:<scheme>`, `STOCK:<name>`,
  /// `US:<ticker>`, `AGG:INDMONEY:<class>` or `manual:<uuid>`.
  TextColumn get identifier => text().unique()();

  /// Units are not money, so a real is fine here.
  RealColumn get units => real().nullable()();
  IntColumn get valueMinor => integer().nullable()();
  IntColumn get investedMinor => integer().nullable()();

  /// Epoch ms (noon IST for statements).
  IntColumn get asOf => integer().nullable()();

  /// `SMS`, `EMAIL`, `STATEMENT` or `MANUAL`.
  TextColumn get source => text()();
  TextColumn get note => text().nullable()();
  IntColumn get updatedAt => integer()();
  IntColumn get previousValueMinor => integer().nullable()();
  IntColumn get previousAsOf => integer().nullable()();
}

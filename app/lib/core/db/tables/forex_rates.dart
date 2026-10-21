import 'package:drift/drift.dart';

/// User rates per (currency, IST epoch day) (FR-23-01).
@DataClassName('ForexRateRow')
class ForexRates extends Table {
  TextColumn get currency => text()();
  IntColumn get day => integer()();
  RealColumn get inrPerUnit => real()();

  @override
  Set<Column> get primaryKey => {currency, day};
}

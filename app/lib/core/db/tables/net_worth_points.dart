import 'package:drift/drift.dart';

/// One recorded net worth point per day (FR-16-05).
@DataClassName('NetWorthPointRow')
class NetWorthPoints extends Table {
  /// Epoch day (IST), primary key.
  IntColumn get day => integer()();
  IntColumn get assetsMinor => integer()();
  IntColumn get liabilitiesMinor => integer()();

  @override
  Set<Column> get primaryKey => {day};
}

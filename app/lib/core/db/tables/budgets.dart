import 'package:drift/drift.dart';

/// One monthly limit per spendable category (FR-10-09).
@DataClassName('BudgetRow')
class Budgets extends Table {
  /// `Category` enum name (`SNAKE_UPPER`), primary key.
  TextColumn get category => text()();
  IntColumn get monthlyLimitMinor => integer()();

  @override
  Set<Column> get primaryKey => {category};
}

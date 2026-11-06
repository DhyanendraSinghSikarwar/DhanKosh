import 'package:drift/drift.dart';

/// Names the user chose to show instead of a payee's raw name (FR-09-20).
/// The key is the merchant rule key (`MerchantRule.keyOf`).
@DataClassName('MerchantAliasRow')
class MerchantAliases extends Table {
  TextColumn get merchantKey => text()();
  TextColumn get alias => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {merchantKey};
}

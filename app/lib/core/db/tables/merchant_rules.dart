import 'package:drift/drift.dart';

/// Learned and manual category rules (FR-09).
@DataClassName('MerchantRuleRow')
class MerchantRules extends Table {
  TextColumn get merchantKey => text()();
  TextColumn get category => text()();
  IntColumn get updatedAt => integer()();
  TextColumn get matchType => text().withDefault(const Constant('EXACT'))();
  TextColumn get subcategory => text().nullable()();
  IntColumn get customCategoryId => integer().nullable()();
  BoolColumn get manual => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {merchantKey};
}

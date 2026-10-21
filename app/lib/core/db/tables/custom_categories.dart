import 'package:drift/drift.dart';

/// User-made categories (FR-09-13).
@DataClassName('CustomCategoryRow')
class CustomCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get colorArgb => integer()();
  IntColumn get createdAt => integer()();
}

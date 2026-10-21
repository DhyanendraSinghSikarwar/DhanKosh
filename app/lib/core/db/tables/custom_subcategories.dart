import 'package:drift/drift.dart';

/// User-made sub-categories; parent is a built-in name or `custom:<id>`.
@DataClassName('CustomSubcategoryRow')
class CustomSubcategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get parent => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get createdAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {parent, name},
      ];
}

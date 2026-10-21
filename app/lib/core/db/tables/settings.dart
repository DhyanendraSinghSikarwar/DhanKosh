import 'package:drift/drift.dart';

/// Key-value app settings (FR-26-12). Values are encoded text.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

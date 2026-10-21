import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

void main() {
  test('opens an in-memory database at schema version 3', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 3);
    final rows = await db.customSelect('SELECT 1 AS one').get();
    expect(rows.single.read<int>('one'), 1);
  });
}

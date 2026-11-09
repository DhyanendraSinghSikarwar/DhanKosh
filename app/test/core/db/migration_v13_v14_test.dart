import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v13 database upgrades to v14, receipt column added', () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig14');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');
    final seed = AppDatabase(NativeDatabase(file));
    await dropV14(seed);
    await seed.customStatement('PRAGMA user_version = 13');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final cols = await db.customSelect('PRAGMA table_info(transactions)').get();
    expect(cols.map((c) => c.read<String>('name')), contains('receipt'));
  });
}

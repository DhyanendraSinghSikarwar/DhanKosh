import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v12 database upgrades to v13, auto_post defaults off', () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig13');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');
    final seed = AppDatabase(NativeDatabase(file));
    await dropV13(seed);
    await seed.customStatement('PRAGMA user_version = 12');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final cols = await db.customSelect('PRAGMA table_info(recurring)').get();
    expect(cols.map((c) => c.read<String>('name')), contains('auto_post'));
  });
}

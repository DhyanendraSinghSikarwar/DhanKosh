import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v8 database upgrades to v9, data intact, excluded defaults off',
      () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig9');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');

    final seed = AppDatabase(NativeDatabase(file));
    await seed.into(seed.settings).insert(
          SettingsCompanion.insert(key: 'sms_cursor', value: '9'),
        );
    await dropV9(seed);
    await seed.customStatement('PRAGMA user_version = 8');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(
      (await (db.select(db.settings)..where((t) => t.key.equals('sms_cursor')))
              .getSingle())
          .value,
      '9',
    );
    final cols = await db.customSelect('PRAGMA table_info(transactions)').get();
    expect(cols.map((c) => c.read<String>('name')), contains('excluded'));
  });
}

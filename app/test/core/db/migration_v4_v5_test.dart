import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v4 database upgrades to v5, data intact, log table usable (F-22)',
      () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig5');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');

    final seed = AppDatabase(NativeDatabase(file));
    await seed.into(seed.settings).insert(
          SettingsCompanion.insert(key: 'sms_cursor', value: '7'),
        );
    await dropV5(seed);
    await seed.customStatement('PRAGMA user_version = 4');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(
      (await (db.select(db.settings)..where((t) => t.key.equals('sms_cursor')))
              .getSingle())
          .value,
      '7',
    );
    await db.into(db.activityEntries).insert(
          ActivityEntriesCompanion.insert(at: 1, source: 'SMS_SCAN'),
        );
    final row = await db.select(db.activityEntries).getSingle();
    expect(row.runs, 1);
    expect(row.read, 0);
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name='activity_entries_at'",
        )
        .get();
    expect(idx, hasLength(1));
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 5);
  });
}

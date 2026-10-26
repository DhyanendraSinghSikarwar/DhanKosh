import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v5 database upgrades to v6, data intact, new tables usable (F-36)',
      () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig6');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');

    final seed = AppDatabase(NativeDatabase(file));
    await seed.into(seed.settings).insert(
          SettingsCompanion.insert(key: 'sms_cursor', value: '9'),
        );
    await dropV6(seed);
    await seed.customStatement('PRAGMA user_version = 5');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(
      (await (db.select(db.settings)..where((t) => t.key.equals('sms_cursor')))
              .getSingle())
          .value,
      '9',
    );
    final g = await db.into(db.goals).insert(
          GoalsCompanion.insert(
            name: 'Trip',
            targetMinor: 500000,
            createdAt: 1,
          ),
        );
    await db.into(db.goalContributions).insert(
          GoalContributionsCompanion.insert(
            goalId: g,
            amountMinor: 10000,
            day: 20000,
            createdAt: 1,
          ),
        );
    await db.into(db.sips).insert(
          SipsCompanion.insert(
            name: 'Index fund',
            amountMinor: 500000,
            frequency: 'MONTHLY',
            startDay: 20000,
            createdAt: 1,
          ),
        );
    await db.into(db.mfOrders).insert(
          MfOrdersCompanion.insert(
            identifier: 'MF:index',
            schemeName: 'Index fund',
            at: 1,
          ),
        );
    expect(await db.select(db.goals).get(), hasLength(1));
    expect(await db.select(db.sips).get(), hasLength(1));
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 6);
  });
}

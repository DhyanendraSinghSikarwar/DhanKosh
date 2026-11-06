import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v7 database upgrades to v8, data intact, ignored accounts usable',
      () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig8');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');

    final seed = AppDatabase(NativeDatabase(file));
    await seed.into(seed.settings).insert(
          SettingsCompanion.insert(key: 'sms_cursor', value: '9'),
        );
    await dropV8(seed);
    await seed.customStatement('PRAGMA user_version = 7');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(
      (await (db.select(db.settings)..where((t) => t.key.equals('sms_cursor')))
              .getSingle())
          .value,
      '9',
    );
    await db.into(db.ignoredAccounts).insert(
          IgnoredAccountsCompanion.insert(
            bankName: 'HDFC Bank',
            last4: '1111',
            ignoredAt: 1,
          ),
        );
    expect(await db.select(db.ignoredAccounts).get(), hasLength(1));
  });
}

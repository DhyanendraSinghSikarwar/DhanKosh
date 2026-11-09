import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v14 database upgrades to v15, group and people tables usable',
      () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig15');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');
    final seed = AppDatabase(NativeDatabase(file));
    await dropV15(seed);
    await seed.customStatement('PRAGMA user_version = 14');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.into(db.txGroups).insert(
          TxGroupsCompanion.insert(name: 'Goa', createdAt: 1),
        );
    await db.into(db.people).insert(
          PeopleCompanion.insert(name: 'Asha', createdAt: 1),
        );
    expect(await db.select(db.txGroups).get(), hasLength(1));
    expect(await db.select(db.people).get(), hasLength(1));
  });
}

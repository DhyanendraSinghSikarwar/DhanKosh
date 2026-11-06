import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v9 database upgrades to v10, aliases usable', () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig10');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');

    final seed = AppDatabase(NativeDatabase(file));
    await dropV10(seed);
    await seed.customStatement('PRAGMA user_version = 9');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.into(db.merchantAliases).insert(
          MerchantAliasesCompanion.insert(
            merchantKey: 'swiggy',
            alias: 'Food',
            updatedAt: 1,
          ),
        );
    expect(await db.select(db.merchantAliases).get(), hasLength(1));
  });
}

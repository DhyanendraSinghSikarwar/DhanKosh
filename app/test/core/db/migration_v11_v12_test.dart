import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v11 database upgrades to v12, tag tables usable', () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig12');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');
    final seed = AppDatabase(NativeDatabase(file));
    await dropV12(seed);
    await seed.customStatement('PRAGMA user_version = 11');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.into(db.tags).insert(TagsCompanion.insert(name: 'trip'));
    expect(await db.select(db.tags).get(), hasLength(1));
  });
}

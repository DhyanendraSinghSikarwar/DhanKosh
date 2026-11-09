import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v6 database upgrades to v7, data intact, queue tables usable (F-38)',
      () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig7');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');

    final seed = AppDatabase(NativeDatabase(file));
    await seed.into(seed.settings).insert(
          SettingsCompanion.insert(key: 'sms_cursor', value: '9'),
        );
    await dropV7(seed);
    await seed.customStatement('PRAGMA user_version = 6');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(
      (await (db.select(db.settings)..where((t) => t.key.equals('sms_cursor')))
              .getSingle())
          .value,
      '9',
    );
    await db.into(db.unrecognisedMessages).insert(
          UnrecognisedMessagesCompanion.insert(
            source: 'SMS',
            sender: 'VM-NEWBNK-S',
            senderKey: 'NEWBNK',
            sourceMessageId: 'sms:1',
            bodyHash: 'h1',
            body: 'Rs 80 debited',
            receivedAt: 1,
            status: 'FRESH',
            createdAt: 1,
          ),
        );
    await db.into(db.senderPrefs).insert(
          SenderPrefsCompanion.insert(
            senderKey: 'NEWBNK',
            state: 'LEARNED',
            last4: const Value('4821'),
            updatedAt: 1,
          ),
        );
    expect(await db.select(db.unrecognisedMessages).get(), hasLength(1));
    expect(await db.select(db.senderPrefs).get(), hasLength(1));
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 15);
  });
}

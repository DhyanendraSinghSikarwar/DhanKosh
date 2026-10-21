import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

void main() {
  test('v1 database upgrades through v3 with data intact (F-03, Phase 3)',
      () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');

    // Build a v1 file: the v2 schema minus the new table, user_version 1.
    final v2 = AppDatabase(NativeDatabase(file));
    await v2.into(v2.settings).insert(
          SettingsCompanion.insert(key: 'sms_cursor', value: '123'),
        );
    await v2.customStatement('DROP TABLE processed_emails');
    for (final t in [
      'statements',
      'holdings',
      'net_worth_points',
      'card_due_notices',
      'card_overrides',
    ]) {
      await v2.customStatement('DROP TABLE $t');
    }
    await v2.customStatement('PRAGMA user_version = 1');
    await v2.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    // Opening triggers onUpgrade(1 -> 2).
    final row = await (db.select(db.settings)
          ..where((t) => t.key.equals('sms_cursor')))
        .getSingle();
    expect(row.value, '123');
    await db.into(db.processedEmails).insert(
          ProcessedEmailsCompanion.insert(
            messageId: 'imap:<a@x>',
            processedAt: 1,
            outcome: 'PARSED',
          ),
        );
    expect(await db.select(db.processedEmails).get(), hasLength(1));
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 3);
  });
}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v2 database with data upgrades to v3, data intact (Phase 3)', () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');

    final seed = AppDatabase(NativeDatabase(file));
    await seed.into(seed.settings).insert(
          SettingsCompanion.insert(key: 'sms_cursor', value: '9'),
        );
    await seed.into(seed.processedEmails).insert(
          ProcessedEmailsCompanion.insert(
            messageId: 'imap:<a@x>',
            processedAt: 1,
            outcome: 'PARSED',
          ),
        );
    for (final t in [
      'statements',
      'holdings',
      'net_worth_points',
      'card_due_notices',
      'card_overrides',
    ]) {
      await seed.customStatement('DROP TABLE $t');
    }
    await dropV4(seed);
    await seed.customStatement('PRAGMA user_version = 2');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(
      (await (db.select(db.settings)..where((t) => t.key.equals('sms_cursor')))
              .getSingle())
          .value,
      '9',
    );
    expect(await db.select(db.processedEmails).get(), hasLength(1));
    // New tables exist and accept rows.
    await db.into(db.holdings).insert(
          HoldingsCompanion.insert(
            kind: 'STOCK',
            name: 'X',
            identifier: 'INE002A01018',
            source: 'MANUAL',
            updatedAt: 1,
          ),
        );
    await db.into(db.netWorthPoints).insert(
          NetWorthPointsCompanion.insert(
            day: const Value(1),
            assetsMinor: 1,
            liabilitiesMinor: 0,
          ),
        );
    expect(await db.select(db.holdings).get(), hasLength(1));
    expect(await db.select(db.statements).get(), isEmpty);
    expect(await db.select(db.cardDueNotices).get(), isEmpty);
    expect(await db.select(db.cardOverrides).get(), isEmpty);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 5);
  });
}

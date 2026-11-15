import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v15 database upgrades to v16, transfer direction column added',
      () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig16');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');
    final seed = AppDatabase(NativeDatabase(file));
    await dropV16(seed);
    await seed.customStatement('PRAGMA user_version = 15');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.customStatement(
      'INSERT INTO transactions (amount_minor, currency, type, bank_name, '
      'account_kind, channel, timestamp, has_explicit_time, category, '
      'transaction_hash, confidence, created_at, transfer_dir) VALUES '
      "(100, 'INR', 'TRANSFER', 'X', 'ACCOUNT', 'OTHER', 1, 1, 'TRANSFER', "
      "'h', 1, 1, -1)",
    );
    final r = await db.select(db.transactions).get();
    expect(r.single.transferDir, -1);
  });
}

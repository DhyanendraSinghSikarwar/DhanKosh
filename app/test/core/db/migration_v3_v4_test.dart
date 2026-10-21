import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/db/app_database.dart';

import '../../support/v4_schema.dart';

void main() {
  test('v3 database upgrades to v4, data intact, rates backfilled (Phase 4)',
      () async {
    final dir = Directory.systemTemp.createTempSync('hisaab_mig4');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/h.db');

    final seed = AppDatabase(NativeDatabase(file));
    await seed.into(seed.settings).insert(
          SettingsCompanion.insert(key: 'sms_cursor', value: '9'),
        );
    Future<void> tx(String hash, String cur, int amt) =>
        seed.into(seed.transactions).insert(
              TransactionsCompanion.insert(
                amountMinor: amt,
                currency: cur,
                type: 'DEBIT',
                bankName: 'HDFC Bank',
                accountKind: 'ACCOUNT',
                channel: 'UPI',
                timestamp: 1790310600000,
                hasExplicitTime: true,
                category: 'FOOD',
                transactionHash: hash,
                confidence: 0.9,
                createdAt: 1,
              ),
            );
    await dropV4(seed);
    await tx('a', 'INR', 25000);
    await tx('b', 'USD', 1000);
    await seed.customStatement('PRAGMA user_version = 3');
    await seed.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(
      (await (db.select(db.settings)..where((t) => t.key.equals('sms_cursor')))
              .getSingle())
          .value,
      '9',
    );
    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(2));
    expect(rows.firstWhere((r) => r.currency == 'INR').inrMinor, 25000);
    expect(rows.firstWhere((r) => r.currency == 'USD').inrMinor, isNull);

    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(category: 'FOOD', monthlyLimitMinor: 100),
        );
    await db.into(db.forexRates).insert(
          ForexRatesCompanion.insert(
            currency: 'USD',
            day: 20000,
            inrPerUnit: 80,
          ),
        );
    final t = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='trigger' "
          "AND name LIKE 'transactions_inr_%'",
        )
        .get();
    expect(t, hasLength(2));
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 5);
  });
}

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

void main() {
  test('repositories resolve over an overridden in-memory database', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final txs = container.read(transactionRepositoryProvider);
    final accounts = container.read(accountRepositoryProvider);
    final settings = container.read(settingsRepositoryProvider);
    final rules =
        await container.read(categoryRepositoryProvider).loadRuleSet();
    expect(await txs.watchRecent(5).first, isEmpty);
    expect(await accounts.watchVisible().first, isEmpty);
    expect(await settings.read(SettingKeys.smsEnabled), isTrue);
    expect(rules.rules, isEmpty);
  });
}

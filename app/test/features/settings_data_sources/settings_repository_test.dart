import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  // FR-26-12
  test('reads return defaults before anything is saved', () async {
    expect(await env.settings.read(SettingKeys.smsEnabled), isTrue);
    expect(await env.settings.read(SettingKeys.hideAmounts), isTrue);
    expect(await env.settings.read(SettingKeys.appNotifications), isFalse);
    expect(await env.settings.read(SettingKeys.historyDays), 90);
    expect(await env.settings.read(SettingKeys.lastSmsResult), '');
  });

  test('typed values round-trip and stream', () async {
    final seen = env.settings.watch(SettingKeys.historyDays);
    expect(await seen.first, 90);
    await env.settings.write(SettingKeys.historyDays, 30);
    expect(await seen.first, 30);
    await env.settings.write(SettingKeys.smsEnabled, false);
    await env.settings.write(SettingKeys.lastSmsResult, '2 new, 1 merged');
    expect(await env.settings.read(SettingKeys.smsEnabled), isFalse);
    expect(
      await env.settings.read(SettingKeys.lastSmsResult),
      '2 new, 1 merged',
    );
    const tags = SettingKey<Set<String>>('tags', {});
    await env.settings.write(tags, {'a', 'b'});
    expect(await env.settings.read(tags), {'a', 'b'});
  });

  // FR-26-14
  test('sms cursor only increases until reset', () async {
    await env.settings.write(SettingKeys.smsCursor, 500);
    await env.settings.write(SettingKeys.smsCursor, 100);
    expect(await env.settings.read(SettingKeys.smsCursor), 500);
    await env.settings.remove(SettingKeys.smsCursor);
    expect(await env.settings.read(SettingKeys.smsCursor), 0);
  });

  // FR-26-13
  test('capped list keeps the newest entries', () async {
    for (var i = 0; i < 5; i++) {
      await env.settings.appendCapped('alerted_keys', 'k$i', cap: 3);
    }
    expect(await env.settings.readList('alerted_keys'), ['k2', 'k3', 'k4']);
  });
}

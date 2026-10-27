import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/history_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/sender_providers.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/usecases/change_history_days.dart';
import 'package:hisaab/features/settings_data_sources/presentation/history_days_card.dart';
import 'package:hisaab/features/settings_data_sources/presentation/sender_lists_screen.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/sender_overrides.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';

import '../../support/pipeline_fakes.dart';
import '../../support/test_env.dart';

class _Reread implements HistoryReread {
  final log = <String>[];
  @override
  Future<void> resetPositions() async => log.add('reset');
  @override
  Future<void> start() async => log.add('start');
}

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('History to read (FR-26-30)', () {
    test('raising re-reads, lowering and no change do not', () async {
      final reread = _Reread();
      final change = ChangeHistoryDays(env.settings, reread);
      expect(await env.settings.read(SettingKeys.historyDays), 90);
      expect(await change(180), isTrue);
      expect(reread.log, ['reset', 'start']);
      expect(await env.settings.read(SettingKeys.historyDays), 180);
      reread.log.clear();
      expect(await change(30), isFalse);
      expect(await change(30), isFalse);
      expect(reread.log, isEmpty);
      expect(await env.settings.read(SettingKeys.historyDays), 30);
    });

    test('clamped to 7..365', () async {
      final reread = _Reread();
      final change = ChangeHistoryDays(env.settings, reread);
      await change(1000);
      expect(await env.settings.read(SettingKeys.historyDays), 365);
      await change(2);
      expect(await env.settings.read(SettingKeys.historyDays), 7);
    });

    test('the SMS cursor goes back to zero so the window is read again',
        () async {
      await env.settings.write(SettingKeys.smsCursor, 999);
      await env.settings.remove(SettingKeys.smsCursor);
      expect(await env.settings.read(SettingKeys.smsCursor), 0);
    });
  });

  group('Sender overrides (FR-26-31)', () {
    test('input is normalised: ids upper-case, domains lower-case', () {
      expect(SenderOverrides.normalize(' zzcoop '), 'ZZCOOP');
      expect(SenderOverrides.normalize('AX-zzcoop-S'), 'ZZCOOP');
      expect(
        SenderOverrides.normalize('Alerts@MyBank.Example'),
        'mybank.example',
      );
      expect(SenderOverrides.normalize('mybank.example'), 'mybank.example');
      expect(SenderOverrides.normalize('a b'), isNull);
      expect(SenderOverrides.normalize(''), isNull);
      expect(SenderOverrides.normalize('x.'), isNull);
    });

    test('store round trip and reset', () async {
      final store = KvSenderOverridesStore(SettingsKeyValueStore(env.settings));
      expect((await store.read()).isEmpty, isTrue);
      await store.save(
        const SenderOverrides(added: {'ZZCOOP'}, removed: {'HDFCBK'}),
      );
      final o = await store.read();
      expect(o.added, {'ZZCOOP'});
      expect(o.removed, {'HDFCBK'});
      await store.save(SenderOverrides.none);
      expect((await store.read()).isEmpty, isTrue);
    });

    test('pre-filter: added sender passes and is parsed, removed is blocked',
        () async {
      final cache = SenderOverridesCache(
        KvSenderOverridesStore(SettingsKeyValueStore(env.settings)),
      );
      final ingest = IngestMessage(ledger: env.txs, senderOverrides: cache);
      await ingest.prepare();
      const sender = 'AX-ZZCOOP-S';
      const body = 'Rs.450.00 has been debited from account **1234 to VPA '
          'shop@icici DEMO STORE on 20-10-26. Your UPI transaction reference '
          'number is 000000000001.';
      expect(ingest.accepts(sender), isFalse);
      expect(ingest.accepts('AX-HDFCBK-S'), isTrue);

      await cache.save(
        const SenderOverrides(added: {'ZZCOOP'}, removed: {'HDFCBK'}),
      );
      expect(ingest.accepts(sender), isTrue);
      expect(ingest.accepts('AX-HDFCBK-S'), isFalse);
      final d = await ingest.detail(
        InboxSms(sender: sender, body: body, receivedAt: env.clock),
      );
      expect(d.parse.transaction, isNotNull);
      expect(await env.count('transactions'), 1);

      await cache.save(SenderOverrides.none);
      expect(ingest.accepts(sender), isFalse);
      expect(ingest.accepts('AX-HDFCBK-S'), isTrue);
    });
  });

  group('screens', () {
    Future<ProviderContainer> pump(WidgetTester t, Widget home) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(800, 2400);
      addTearDown(t.view.reset);
      final h = PipelineHarness();
      addTearDown(h.dispose);
      final c = ProviderContainer(
        overrides: [
          ...h.overrides,
          settingsRepositoryProvider.overrideWithValue(env.settings),
          changeHistoryDaysProvider.overrideWithValue(
            ChangeHistoryDays(env.settings, _Reread()),
          ),
        ],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: home)),
          ),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
      return c;
    }

    Future<void> tap(WidgetTester t, String key) async {
      await t.runAsync(() async {
        await t.tap(find.byKey(Key(key)));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pump();
    }

    testWidgets('history card picks a window and says it reads again',
        (t) async {
      await pump(t, const HistoryDaysCard());
      expect(find.text('90 days'), findsOneWidget);
      await tap(t, 'history-365');
      expect(find.text('365 days'), findsOneWidget);
      expect(find.byKey(const Key('history-message')), findsOneWidget);
      await tap(t, 'history-30');
      expect(find.text('30 days'), findsOneWidget);
      expect(find.byKey(const Key('history-message')), findsNothing);
      expect(await env.settings.read(SettingKeys.historyDays), 30);
    });

    testWidgets('sender lists: add, switch a default off, reset (FR-26-31)',
        (t) async {
      final c = await pump(t, const SizedBox());
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: SenderListsScreen()),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await t.pump();

      await t.enterText(find.byKey(const Key('senders-sms-input')), 'zzcoop');
      await tap(t, 'senders-sms-add');
      expect(find.byKey(const Key('senders-sms-added-ZZCOOP')), findsOneWidget);
      expect(c.read(senderOverridesCacheProvider).current.added, {
        'ZZCOOP',
      });

      await t.enterText(find.byKey(const Key('senders-sms-input')), 'a b');
      await tap(t, 'senders-sms-add');
      expect(find.text('Not a valid entry.'), findsOneWidget);

      final first = defaultSenderKeys().sms.first;
      await tap(t, 'senders-sms-default-$first');
      expect(
        c.read(senderOverridesCacheProvider).current.removed,
        {first},
      );
      await tap(t, 'senders-sms-reset');
      expect(c.read(senderOverridesCacheProvider).current.isEmpty, isTrue);

      await tap(t, 'senders-tab-mail');
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('senders-mail-input')),
        'mybank.example',
      );
      await tap(t, 'senders-mail-add');
      expect(
        find.byKey(const Key('senders-mail-added-mybank.example')),
        findsOneWidget,
      );
      await tap(t, 'senders-mail-reset');
      expect(
        find.byKey(const Key('senders-mail-added-mybank.example')),
        findsNothing,
      );
    });
  });
}

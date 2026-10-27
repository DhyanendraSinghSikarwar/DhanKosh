import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/core/platform_channels/sms_channel.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_inbox_source_impl.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_settings_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';

class MemKv implements KeyValueStore {
  final map = <String, String>{};
  @override
  Future<String?> getString(String key) async => map[key];
  @override
  Future<void> setString(String key, String value) async => map[key] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = SmsChannel();
  tearDown(() => messenger.setMockMethodCallHandler(channel.channel, null));

  Map<String, Object?> row(int id, String sender) => {
        'id': '$id',
        'sender': sender,
        'body': 'b$id',
        'timestamp': 1000 + id,
        'sentTimestamp': 0,
      };

  test('inbox source pages until done and filters senders (FR-02-09)',
      () async {
    final calls = <Map<Object?, Object?>>[];
    messenger.setMockMethodCallHandler(channel.channel, (call) async {
      final args = call.arguments as Map<Object?, Object?>;
      calls.add(args);
      return calls.length == 1
          ? {
              'items': [row(1, 'VM-HDFCBK-S'), row(2, 'VM-AMAZON')],
              'examined': 4,
              'nextSince': 1002,
              'nextAfterId': 2,
              'done': false,
            }
          : {
              'items': [row(3, 'VM-HDFCBK-S')],
              'examined': 1,
              'nextSince': 1003,
              'nextAfterId': 3,
              'done': true,
            };
    });
    final batches = <int>[];
    final stats = await const SmsInboxSourceImpl(channel).readBatches(
      since: 500,
      batchSize: 2,
      accept: (s) => s.contains('BK'),
      onBatch: (b) async => batches.add(b.length),
    );
    expect(batches, [1, 1]);
    expect(stats.examined, 5);
    expect(stats.lastTimestamp, 1003);
    expect(calls[1]['sinceMillis'], 1002);
    expect(calls[1]['afterId'], 2);
  });

  test('permission error becomes PermissionFailure', () async {
    messenger.setMockMethodCallHandler(
      channel.channel,
      (_) async => throw PlatformException(code: 'permission'),
    );
    await expectLater(
      const SmsInboxSourceImpl(channel).readBatches(
        since: 0,
        batchSize: 1,
        accept: (_) => true,
        onBatch: (_) async {},
      ),
      throwsA(isA<PermissionFailure>()),
    );
  });

  test('settings store defaults, round trip, monotonic cursor', () async {
    final store = SmsSettingsStore(MemKv());
    var s = await store.read();
    expect([s.enabled, s.cursor, s.lookbackDays], [true, 0, 90]);
    await store.setEnabled(enabled: false);
    await store.saveScan(cursor: 50, lastScanAt: 9, lastResult: 'ok');
    await store.saveScan(cursor: 20, lastScanAt: 10, lastResult: 'ok2');
    await store.setLookbackDays(30);
    await store.setLookbackDays(400); // out of range, ignored
    s = await store.read();
    expect(s.enabled, isFalse);
    expect(s.cursor, 50);
    expect(s.lastScanAt, 10);
    expect(s.lookbackDays, 30);
  });
}

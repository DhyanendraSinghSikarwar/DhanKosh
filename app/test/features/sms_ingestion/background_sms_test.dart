import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/platform_channels/background_channel.dart';
import 'package:hisaab/core/platform_channels/background_tasks.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_scan_scheduler_impl.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_settings_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/nightly_schedule.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/drain_pending_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/handle_live_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/sms_engine.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/pipeline_fakes.dart';
import '../../support/test_env.dart';

class _Scheduler implements SmsScanScheduler {
  final log = <String>[];
  @override
  Future<void> scheduleNightly() async => log.add('on');
  @override
  Future<void> cancelNightly() async => log.add('off');
}

class _Live extends FakeLive {
  final pending = <InboxSms>[];
  @override
  Future<List<InboxSms>> drainPending() async {
    final out = [...pending];
    pending.clear();
    return out;
  }
}

// FR-02-01, FR-02-10, FR-02-14.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t0 = DateTime.now().millisecondsSinceEpoch - 3600000;

  group('nightly schedule (FR-02-14)', () {
    test('before 02:30 runs today, after it tomorrow', () {
      expect(
        nextNightlyDelay(DateTime(2026, 10, 21, 1)),
        const Duration(hours: 1, minutes: 30),
      );
      expect(
        nextNightlyDelay(DateTime(2026, 10, 21, 2, 30)),
        const Duration(hours: 24),
      );
      expect(
        nextNightlyDelay(DateTime(2026, 10, 21, 23)),
        const Duration(hours: 3, minutes: 30),
      );
    });

    test('scheduler registers a 24 h battery-aware job at 02:30', () async {
      const channel = MethodChannel('com.hisaab/background');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
        calls.add(c);
        return null;
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final s = SmsScanSchedulerImpl(
        const BackgroundChannel(),
        now: () => DateTime(2026, 10, 21, 1),
      );
      await s.scheduleNightly();
      await s.cancelNightly();
      final a = calls.first.arguments as Map;
      expect(calls.first.method, 'schedulePeriodic');
      expect(a['uniqueName'], BackgroundTasks.nightlyUnique);
      expect(a['task'], BackgroundTasks.smsNightly);
      expect(a['intervalMinutes'], 1440);
      expect(a['initialDelayMinutes'], 90);
      expect(a['requiresBatteryNotLow'], isTrue);
      expect(calls.last.method, 'cancel');
    });
  });

  group('engine schedules by sms_enabled (FR-02-14, FR-02-05)', () {
    late TestEnv env;
    late SmsSettingsStore settings;
    late _Scheduler scheduler;
    late SmsEngine engine;

    setUp(() {
      env = TestEnv();
      settings = SmsSettingsStore(SettingsKeyValueStore(env.settings));
      scheduler = _Scheduler();
      final ingest = IngestMessage(ledger: env.txs);
      engine = SmsEngine(
        live: _Live(),
        settings: settings,
        handle: HandleLiveSms(
          settings: settings,
          accept: ingest.accepts,
          ingest: ingest.call,
        ),
        scan: () => ScanSms(
          inbox: FakeInbox([]),
          settings: settings,
          accept: ingest.accepts,
          ingest: ingest.call,
        ),
        senderPattern: SmsEngine.senderPatternDefault,
        scheduler: scheduler,
      );
    });
    tearDown(() async {
      await engine.stop();
      await env.close();
    });

    test('nightly stays registered while SMS is paused (FR-03-17)', () async {
      await engine.start();
      await engine.setEnabled(enabled: false);
      await engine.setEnabled(enabled: true);
      expect(scheduler.log, ['on', 'on', 'on']);
    });
  });

  group('drain pending (AC-02-01)', () {
    late TestEnv env;
    late SmsSettingsStore settings;
    late _Live live;
    late DrainPendingSms drain;

    InboxSms msg(String ref, {String sender = 'VM-HDFCBK'}) => InboxSms(
          sender: sender,
          body: 'Rs.500.00 debited from A/c XX1234 on 20-10-26 '
              'UPI Ref $ref to DEMO STORE',
          receivedAt: t0,
          sentAt: t0,
        );

    setUp(() {
      env = TestEnv();
      settings = SmsSettingsStore(SettingsKeyValueStore(env.settings));
      live = _Live();
      final ingest = IngestMessage(ledger: env.txs);
      drain = DrainPendingSms(
        live: live,
        handle: HandleLiveSms(
          settings: settings,
          accept: ingest.accepts,
          ingest: ingest.call,
        ),
      );
    });
    tearDown(() => env.close());

    test('queued messages land in the ledger once, queue is cleared', () async {
      live.pending
        ..add(msg('000000000011'))
        ..add(msg('000000000011')) // same message twice: one row
        ..add(msg('000000000012'))
        ..add(msg('000000000013', sender: 'VM-AMAZON')); // not a bank
      expect(await drain(), 3);
      expect(await env.count('transactions'), 2);
      expect(live.pending, isEmpty);
    });

    test('paused SMS reading ingests nothing', () async {
      await settings.setEnabled(enabled: false);
      live.pending.add(msg('000000000014'));
      expect(await drain(), 0);
      expect(await env.count('transactions'), 0);
    });
  });

  group('batch parse off the UI isolate (FR-02-10)', () {
    late TestEnv env;
    setUp(() => env = TestEnv());
    tearDown(() => env.close());

    List<InboxSms> batch(int n) => [
          for (var i = 0; i < n; i++)
            InboxSms(
              sender: i.isEven ? 'VM-HDFCBK' : 'AX-ICICIB',
              body: i % 7 == 0
                  ? '123456 is your OTP for txn of Rs.500.00. Do not share.'
                  : 'Rs.${100 + i}.00 debited from A/c XX1234 on 20-10-26 '
                      'UPI Ref ${900000000000 + i} to DEMO STORE $i',
              receivedAt: t0 + i,
              sentAt: t0 + i,
            ),
        ];

    test('isolate parse equals sequential parse', () async {
      final ingest = IngestMessage(ledger: env.txs);
      final msgs = batch(IngestMessage.isolateThreshold + 10);
      final viaIsolate = await ingest.parseAll(msgs);
      expect(viaIsolate, hasLength(msgs.length));
      for (var i = 0; i < msgs.length; i++) {
        final m = msgs[i];
        final seq = parse(Source.sms, m.sender, m.body, m.receivedAt);
        expect(viaIsolate[i].runtimeType, seq.runtimeType, reason: '$i');
        expect(
          viaIsolate[i].transaction?.transactionHash,
          seq.transaction?.transactionHash,
          reason: '$i',
        );
        expect(
          viaIsolate[i].transaction?.amountMinor,
          seq.transaction?.amountMinor,
          reason: '$i',
        );
      }
    });

    test('ingestBatch stores like per-message ingest', () async {
      final ingest = IngestMessage(ledger: env.txs);
      final msgs = batch(IngestMessage.isolateThreshold + 10);
      final details = await ingest.ingestBatch(msgs);
      final rejected =
          details.where((d) => d.outcome == IngestOutcome.rejected).length;
      expect(details, hasLength(msgs.length));
      expect(await env.count('transactions'), msgs.length - rejected);
      // Re-running is idempotent.
      final again = await ingest.ingestBatch(msgs);
      expect(
        again.where((d) => d.outcome == IngestOutcome.skipped).length,
        msgs.length - rejected,
      );
    });
  });
}

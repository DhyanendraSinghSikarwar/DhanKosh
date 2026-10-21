import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_settings_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/handle_live_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/sms_engine.dart';

import '../../support/pipeline_fakes.dart';
import '../../support/test_env.dart';

class _Live extends FakeLive {
  final pending = <InboxSms>[];
  final controller = StreamController<InboxSms>.broadcast();
  @override
  Stream<InboxSms> get live => controller.stream;
  @override
  Future<List<InboxSms>> drainPending() async {
    final out = [...pending];
    pending.clear();
    return out;
  }
}

void main() {
  late TestEnv env;
  late _Live live;
  late SmsEngine engine;
  late SmsSettingsStore settings;
  late FakeInbox inbox;
  final t = DateTime.now().millisecondsSinceEpoch - 60000;

  InboxSms sms(String ref) => InboxSms(
        sender: 'VM-HDFCBK',
        body: 'Rs.500.00 debited from A/c XX1234 on 20-10-26 '
            'UPI Ref $ref to DEMO STORE',
        receivedAt: t,
        sentAt: t,
      );

  setUp(() {
    env = TestEnv();
    live = _Live();
    settings = SmsSettingsStore(SettingsKeyValueStore(env.settings));
    final ingest = IngestMessage(ledger: env.txs);
    inbox = FakeInbox([sms('000000000099')]);
    engine = SmsEngine(
      live: live,
      settings: settings,
      handle: HandleLiveSms(
        settings: settings,
        accept: ingest.accepts,
        ingest: ingest.call,
      ),
      scan: () => ScanSms(
        inbox: inbox,
        settings: settings,
        accept: ingest.accepts,
        ingest: ingest.call,
      ),
      senderPattern: SmsEngine.senderPatternDefault,
    );
  });
  tearDown(() async {
    await engine.stop();
    await env.close();
  });

  test('start configures native, drains queue, catches up (FR-02-05, FR-02-13)',
      () async {
    live.pending.add(sms('000000000001'));
    await engine.start();
    expect(live.enabled, isTrue);
    expect(engine.running, isTrue);
    // one drained + one from the 14-day catch-up scan
    expect(await env.count('transactions'), 2);
  });

  test('live messages ingest; pause stops them (FR-02-05)', () async {
    await engine.start();
    live.controller.add(sms('000000000002'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(await env.count('transactions'), 2);
    await engine.setEnabled(enabled: false);
    expect(live.enabled, isFalse);
    live.controller.add(sms('000000000003'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(await env.count('transactions'), 2);
  });

  test('scan outcome counts feed the summary (FR-02-11)', () async {
    final ingest = IngestMessage(ledger: env.txs);
    final r = await ScanSms(
      inbox: inbox,
      settings: settings,
      accept: ingest.accepts,
      ingest: ingest.call,
    )(const SmsScanRequest.full());
    expect(r.inserted, 1);
    expect(r.summary, contains('1 new'));
  });
}

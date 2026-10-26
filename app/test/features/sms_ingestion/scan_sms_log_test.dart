import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_settings_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';
import 'package:hisaab/shared/log/app_logger.dart';

import '../../support/pipeline_fakes.dart';
import '../../support/test_env.dart';

class _ListSink implements LogSink {
  final lines = <String>[];
  @override
  void append(String line) => lines.add(line);
}

void main() {
  test('scan logs counts, never the message (FR-35-20)', () async {
    final env = TestEnv();
    addTearDown(env.close);
    final t = DateTime.now().millisecondsSinceEpoch - 60000;
    const body = 'Rs.500.00 debited from A/c XX1234 on 20-10-26 '
        'UPI Ref 000000000077 to DEMO STORE';
    final ingest = IngestMessage(ledger: env.txs);
    final sink = _ListSink();
    final r = await ScanSms(
      inbox: FakeInbox([
        InboxSms(sender: 'VM-HDFCBK', body: body, receivedAt: t, sentAt: t),
      ]),
      settings: SmsSettingsStore(SettingsKeyValueStore(env.settings)),
      accept: ingest.accepts,
      ingest: ingest.call,
      log: SinkAppLogger(sink),
    )(const SmsScanRequest.recent(14));
    expect(r.inserted, 1);
    final out = sink.lines.join('\n');
    expect(out, contains('scan.start'));
    expect(out, contains('scan.done'));
    expect(out, contains('added=1'));
    for (final bad in ['DEMO', 'STORE', '500', '000000000077', 'XX1234']) {
      expect(out, isNot(contains(bad)), reason: bad);
    }
  });
}

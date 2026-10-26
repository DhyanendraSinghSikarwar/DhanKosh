import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/activity_log/data/activity_log_repository_impl.dart';
import 'package:hisaab/features/activity_log/domain/activity_stats.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_settings_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';

import '../../support/pipeline_fakes.dart';
import '../../support/test_env.dart';

void main() {
  // FR-22-15: unparseable bank-like messages become a problem entry with a
  // count and the sender code only.
  test('scan records problems without message text', () async {
    final env = TestEnv();
    addTearDown(env.close);
    final log = ActivityLogRepositoryImpl(env.db);
    final t = DateTime.now().millisecondsSinceEpoch - 60000;
    const body = 'HDFC Bank: your statement for card ending 9876 is ready '
        'Rs 12345.67 secret-token';
    final ingest = IngestMessage(ledger: env.txs);
    await ScanSms(
      inbox: FakeInbox([
        InboxSms(sender: 'VM-HDFCBK', body: body, receivedAt: t, sentAt: t),
        InboxSms(sender: 'VM-HDFCBK', body: body, receivedAt: t + 1, sentAt: t),
      ]),
      settings: SmsSettingsStore(SettingsKeyValueStore(env.settings)),
      accept: ingest.accepts,
      ingest: ingest.call,
      activity: log,
    )(const SmsScanRequest.recent(14));
    final entries = await log.watch().first;
    final problems =
        entries.where((e) => e.source == ActivitySource.problems).toList();
    expect(problems, hasLength(1));
    expect(problems.single.read, 2);
    expect(problems.single.note, 'VM-HDFCBK');
    final text = ActivityStats.subtitle(problems.single);
    expect(text, '2 unreadable from VM-HDFCBK');
    for (final bad in ['9876', '12345', 'secret', 'statement']) {
      expect(text, isNot(contains(bad)));
    }
  });
}

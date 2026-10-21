import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/settings_data_sources/domain/sample_data.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late IngestMessage ingest;
  final t0 = DateTime(2026, 10, 20, 11, 15).millisecondsSinceEpoch;

  setUp(() {
    env = TestEnv();
    ingest = IngestMessage(ledger: env.txs);
  });
  tearDown(() => env.close());

  InboxSms sms(String body, {String sender = 'VM-HDFCBK', int? at}) => InboxSms(
        sender: sender,
        body: body,
        receivedAt: at ?? t0,
        sentAt: at ?? t0,
      );

  const debit = 'Rs.1,250.00 debited from A/c XX1234 on 20-10-26 '
      'UPI Ref 000000000001 to DEMO STORE';

  test('parsed message is inserted (FR-02-02)', () async {
    final d = await ingest.detail(sms(debit));
    expect(d.parse, isA<Parsed>());
    expect(d.outcome, IngestOutcome.inserted);
    expect(d.parse.transaction!.amountMinor, 125000);
    expect(await env.count('transactions'), 1);
  });

  test('OTP is rejected, nothing stored (FR-02-02)', () async {
    final d = await ingest.detail(
      sms('123456 is your OTP for txn of Rs.500.00. Do not share.'),
    );
    expect(d.outcome, IngestOutcome.rejected);
    expect(d.parse, isNot(isA<Parsed>()));
    expect(await env.count('transactions'), 0);
  });

  test('same message twice is skipped (FR-02-20)', () async {
    expect(await ingest(sms(debit)), IngestOutcome.inserted);
    expect(await ingest(sms(debit)), IngestOutcome.skipped);
    expect(await env.count('transactions'), 1);
  });

  test('SMS and email for one payment dedupe (FR-07-02)', () async {
    expect(await ingest(sms(debit)), IngestOutcome.inserted);
    final r = await ingest.detail(
      sms(debit, sender: 'HDFC Bank <alerts@hdfcbank.net>', at: t0 + 60000),
      source: Source.email,
      messageId: 'email:1',
    );
    expect(r.outcome, IngestOutcome.merged);
    expect(await env.count('transactions'), 1);
    expect(await env.count('transaction_sources'), 2);
  });

  test('sample data all lands through the normal path (FR-26-30)', () async {
    final msgs = SampleData.build(DateTime(2026, 10, 21, 12));
    var inserted = 0;
    for (final m in msgs) {
      final d = await ingest.detail(m);
      if (d.outcome == IngestOutcome.inserted) inserted++;
    }
    expect(msgs.length, SampleData.count);
    expect(inserted, SampleData.count);
    final accounts = await env.count('accounts');
    expect(accounts, 2);
  });
}

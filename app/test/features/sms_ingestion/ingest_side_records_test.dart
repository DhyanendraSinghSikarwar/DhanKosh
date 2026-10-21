// FR-14-06 card due notices and FR-06-15 EPF holdings recorded by the
// ingest pipeline (not transactions).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:parser_core/parser_core.dart' show Source;

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late IngestMessage ingest;
  late CardDueRepositoryImpl dues;
  late HoldingRepositoryImpl holdings;
  final t0 = DateTime(2026, 10, 20, 11, 15).millisecondsSinceEpoch;

  setUp(() {
    env = TestEnv();
    dues = CardDueRepositoryImpl(env.db);
    holdings = HoldingRepositoryImpl(env.db);
    ingest = IngestMessage(ledger: env.txs, cardDues: dues, holdings: holdings);
  });
  tearDown(() => env.close());

  InboxSms sms(String body, String sender) =>
      InboxSms(sender: sender, body: body, receivedAt: t0, sentAt: t0);

  const bill = 'Axis Bank Credit Card No. XX3190: Total payment due INR '
      '8,100.00. Minimum payment due INR 405.00. Due date 02-11-2026.';

  test('card bill SMS is recorded as a notice, no transaction (FR-14-06)',
      () async {
    final d = await ingest.detail(sms(bill, 'VM-AXISBK'));
    expect(d.outcome, IngestOutcome.inserted);
    final n = await dues.notices();
    expect(n, hasLength(1));
    expect(n.first.totalDueMinor, 810000);
    expect(n.first.minDueMinor, 40500);
    expect(n.first.last4, '3190');
    expect(await env.count('transactions'), 0);
  });

  test('same bill twice stores one notice (FR-14-06)', () async {
    await ingest.detail(sms(bill, 'VM-AXISBK'));
    await ingest.detail(sms(bill, 'VM-AXISBK'));
    expect(await dues.notices(), hasLength(1));
  });

  test('app notifications never record notices (FR-14-06)', () async {
    final d = await ingest.detail(sms(bill, 'VM-AXISBK'), source: Source.app);
    expect(d.outcome, IngestOutcome.rejected);
    expect(await dues.notices(), isEmpty);
  });

  test('EPFO SMS is recorded as a holding (FR-06-15)', () async {
    final d = await ingest.detail(
      sms(
        'Dear Member, your passbook balance against MH/BAN/0012345/000/0001234 '
            'is Rs. 2,56,250/-. Contribution of Rs. 3,600/- for due month 092026 '
            'has been received.',
        'VM-EPFOHO',
      ),
    );
    expect(d.outcome, IngestOutcome.inserted);
    final list = await holdings.list();
    expect(list, hasLength(1));
    expect(list.first.valueMinor, 25625000);
    expect(await env.count('transactions'), 0);
  });

  test('without repositories behaviour is unchanged', () async {
    final plain = IngestMessage(ledger: env.txs);
    final d = await plain.detail(sms(bill, 'VM-AXISBK'));
    expect(d.outcome, IngestOutcome.rejected);
  });
}

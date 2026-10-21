import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/data/email_settings_store.dart';
import 'package:hisaab/features/email_ingestion/data/processed_email_repository_impl.dart';
import 'package:hisaab/features/email_ingestion/data/secure_email_credential_store.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/email_sync_runner.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/manage_email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/sync_email.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/email_fakes.dart';
import '../../support/pipeline_fakes.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late FakeImap imap;
  late MemSecure secure;
  late EmailSettingsStore settings;
  late SecureEmailCredentialStore creds;
  late SyncEmail sync;
  late DateTime clock;
  final t0 = DateTime(2026, 10, 20, 11, 15);

  const bank = 'HDFC Bank InstaAlerts <alerts@hdfcbank.net>';
  const body = 'Dear Customer,\n\nRs.450.00 has been debited from account '
      '**1234 to VPA shop@icici DEMO STORE on 20-10-26.\n\n'
      'Your UPI transaction reference number is 000000000001.\n';

  RawEmail mail(
    String id, {
    String from = bank,
    String subject = 'Alert',
    String text = body,
    String? html,
    DateTime? at,
  }) =>
      RawEmail(
        id: id,
        from: from,
        subject: subject,
        receivedAt: (at ?? t0).millisecondsSinceEpoch,
        plain: text,
        html: html,
      );

  setUp(() async {
    env = TestEnv();
    imap = FakeImap();
    secure = MemSecure();
    final kv = SettingsKeyValueStore(env.settings);
    settings = EmailSettingsStore(kv);
    creds = SecureEmailCredentialStore(secure);
    clock = DateTime(2026, 10, 21, 9);
    final ingest = IngestMessage(ledger: env.txs);
    sync = SyncEmail(
      imap: imap,
      settings: settings,
      credentials: creds,
      processed: ProcessedEmailRepositoryImpl(env.db),
      ingest: ({
        required sender,
        required body,
        required receivedAt,
        required messageId,
      }) async =>
          (await ingest.detail(
        InboxSms(sender: sender, body: body, receivedAt: receivedAt),
        source: Source.email,
        messageId: messageId,
      ))
              .outcome,
      now: () => clock,
    );
    await ManageEmailAccount(imap: imap, settings: settings, credentials: creds)
        .save(EmailAccount.forAddress('Me@Gmail.com'), 'abcd efgh ijkl mnop');
  });
  tearDown(() => env.close());

  test('not connected reports a code, nothing runs (FR-03-18)', () async {
    await settings.clearAccount();
    final r = await sync();
    expect(r.error, 'not_connected');
    expect(imap.fetches, 0);
  });

  test('stores the password only in secure storage (FR-03-05)', () async {
    expect(secure.map.values, contains('abcdefghijklmnop'));
    final rows = await env.db.select(env.db.settings).get();
    expect(rows.any((r) => r.value.contains('abcdefgh')), isFalse);
    expect(imap.lastPassword, isNull);
    imap.mails = [mail('imap:<a@x>')];
    await sync();
    expect(imap.lastPassword, 'abcdefghijklmnop');
  });

  test('full first sync ingests allowed mail and marks it (FR-03-09/14)',
      () async {
    imap.mails = [
      mail('imap:<a@x>'),
      mail('imap:<b@x>', from: 'promo@shop.example', subject: 'Sale'),
    ];
    final r = await sync();
    expect(r.mode, 'full');
    expect(r.emails, 1);
    expect(r.inserted, 1);
    expect(await env.count('transactions'), 1);
    expect(await env.count('processed_emails'), 1);
    expect(r.summary, startsWith('full: 1 emails, 1 transactions (1 new'));
    expect(await settings.lastSyncAt(), clock.millisecondsSinceEpoch);
    // Look-back: 90 days before now.
    expect(imap.lastSince, clock.subtract(const Duration(days: 90)));
  });

  test('processed ids are skipped, cursor starts a day back (FR-03-10)',
      () async {
    imap.mails = [mail('imap:<a@x>')];
    await sync();
    final first = clock;
    clock = clock.add(const Duration(days: 1));
    final r = await sync();
    expect(r.mode, 'incremental');
    expect(r.emails, 0);
    expect(r.skipped, 1);
    expect(await env.count('transactions'), 1);
    expect(imap.lastSince, first.subtract(const Duration(days: 1)));
  });

  test('non-whitelisted sender is never read; custom sender is (FR-03-12)',
      () async {
    imap.mails = [mail('imap:<c@x>', from: 'bank@mybank.example')];
    expect((await sync()).emails, 0);
    final m = ManageEmailAccount(
      imap: imap,
      settings: settings,
      credentials: creds,
    );
    expect(await m.addSender('MyBank.example'), isTrue);
    expect(await m.addSender('not an address'), isFalse);
    expect(await settings.lastSyncAt(), 0); // position forgotten
    expect((await sync()).emails, 1);
  });

  test('statement-like subject passes from unknown sender (FR-03-13)',
      () async {
    imap.mails = [
      mail(
        'imap:<d@x>',
        from: 'someone@unknown.example',
        subject: 'Consolidated Account Statement',
        text: 'Statement attached for the month.',
      ),
    ];
    final r = await sync();
    expect(r.emails, 1);
    expect(r.parsed, 0);
    expect(await env.count('processed_emails'), 1); // REJECTED, not re-read
  });

  test('HTML-only body is converted to text (FR-03-15)', () async {
    imap.mails = [
      mail(
        'imap:<h@x>',
        text: '',
        html: '<html><head><style>p{}</style></head><body>'
            '<p>Dear Customer,</p><p>Rs.450.00 has been debited from '
            'account **1234 to VPA shop@icici DEMO STORE on 20-10-26.</p>'
            '<p>Your UPI transaction reference number is 000000000001.</p>'
            '</body></html>',
      ),
    ];
    expect((await sync()).inserted, 1);
  });

  test('auth failure keeps cursor and ids, flags sign-in (FR-03-18)', () async {
    imap.mails = [mail('imap:<a@x>')];
    await sync();
    final cursor = await settings.lastSyncAt();
    imap
      ..error = const AuthFailure('sign-in refused')
      ..mails = [mail('imap:<z@x>')];
    clock = clock.add(const Duration(days: 1));
    final r = await sync();
    expect(r.error, 'auth');
    expect(r.ok, isFalse);
    expect(await settings.needsReauth(), isTrue);
    expect(await settings.lastSyncAt(), cursor);
    expect(await env.count('processed_emails'), 1);
  });

  test('network failure is retryable and moves nothing (FR-03-18)', () async {
    imap.error = const NetworkFailure('down');
    final r = await sync();
    expect(r.error, 'network');
    expect(r.retryable, isTrue);
    expect(await settings.lastSyncAt(), 0);
  });

  test('tls failure is final, not retryable', () async {
    imap.error = const TlsFailure('cert');
    final r = await sync();
    expect(r.error, 'tls');
    expect(r.retryable, isFalse);
  });

  test('SMS and email of the same payment make one transaction (FR-03-14)',
      () async {
    final ingest = IngestMessage(ledger: env.txs);
    final smsOut = await ingest(
      InboxSms(
        sender: 'VM-HDFCBK',
        body: 'Sent Rs.450.00\nFrom HDFC Bank A/C *1234\nTo DEMO STORE\n'
            'On 20/10/26\nRef 000000000001\nNot You?',
        receivedAt: t0.millisecondsSinceEpoch,
        sentAt: t0.millisecondsSinceEpoch,
      ),
    );
    expect(smsOut.name, 'inserted');
    imap.mails = [mail('imap:<a@x>')];
    final r = await sync();
    expect(r.inserted, 0);
    expect(r.merged + r.flagged, lessThanOrEqualTo(1));
    expect(await env.count('transactions'), 1);
    expect(await env.count('transaction_sources'), 2);
  });

  test('disconnect wipes the password, keeps transactions (FR-03-06)',
      () async {
    imap.mails = [mail('imap:<a@x>')];
    await sync();
    await ManageEmailAccount(imap: imap, settings: settings, credentials: creds)
        .disconnect();
    expect(await creds.read(), isNull);
    expect(await settings.account(), isNull);
    expect(await env.count('transactions'), 1);
    expect((await sync()).error, 'not_connected');
  });

  test('runner joins concurrent runs and notifies on change', () async {
    imap.mails = [mail('imap:<a@x>')];
    var changed = 0;
    final runner = EmailSyncRunner(sync, onChanged: () => changed++);
    final a = runner.run();
    final b = runner.run();
    expect(identical(a, b), isTrue);
    await a;
    expect(changed, 1);
    expect(runner.running, isFalse);
  });

  test('provider presets and validation (FR-03-01)', () {
    expect(EmailProvider.detect('a@outlook.com'), EmailProvider.outlook);
    expect(EmailProvider.detect('a@corp.example'), EmailProvider.custom);
    expect(
      EmailAccount.forAddress('a@corp.example').imapHost,
      'imap.corp.example',
    );
    expect(EmailAccount.isValidAddress('a@b'), isFalse);
    expect(ManageEmailAccount.validate('bad', 'x'), isNotNull);
    expect(ManageEmailAccount.validate('a@b.co', '  '), isNotNull);
    expect(ManageEmailAccount.validate('a@b.co', 'x y'), isNull);
  });
}

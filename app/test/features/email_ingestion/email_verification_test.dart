import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/data/email_settings_store.dart';
import 'package:hisaab/features/email_ingestion/data/processed_email_repository_impl.dart';
import 'package:hisaab/features/email_ingestion/data/secure_email_credential_store.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/manage_email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/sync_email.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/verify_email.dart';
import 'package:hisaab/features/email_ingestion/domain/verification_code.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/email_fakes.dart';
import '../../support/pipeline_fakes.dart';
import '../../support/test_env.dart';

/// Serves different mail and failures per mailbox.
class _PerAccountImap extends FakeImap {
  final Map<String, List<RawEmail>> byAddress = {};
  final Map<String, Failure> errors = {};
  final List<String> asked = [];
  final Map<String, DateTime> since = {};

  @override
  Future<List<RawEmail>> fetchSince(
    EmailAccount account,
    String password, {
    required DateTime since,
    required bool Function(String from, String subject) accept,
    int limit = 300,
  }) async {
    asked.add(account.address);
    this.since[account.address] = since;
    final e = errors[account.address];
    if (e != null) throw e;
    return (byAddress[account.address] ?? const [])
        .where((m) => accept(m.from, m.subject))
        .toList();
  }
}

void main() {
  group('VerificationCode (FR-03-03)', () {
    late DateTime now;
    late VerificationCode code;
    setUp(() {
      now = DateTime(2026, 10, 27, 9);
      code = VerificationCode(clock: () => now);
    });

    test('six digits, right code passes once and is then used up', () {
      final c = code.issue('a@x.com');
      expect(c, matches(RegExp(r'^[1-9]\d{5}$')));
      expect(code.check('a@x.com', 'wrong'), VerificationResult.wrong);
      expect(code.check('a@x.com', ' $c '), VerificationResult.ok);
      expect(code.check('a@x.com', c), VerificationResult.none);
    });

    test('expires after 10 minutes', () {
      final c = code.issue('a@x.com');
      now = now.add(const Duration(minutes: 9, seconds: 59));
      expect(
        code.check('a@x.com', '000000'),
        VerificationResult.wrong,
      );
      now = now.add(const Duration(seconds: 2));
      expect(code.check('a@x.com', c), VerificationResult.expired);
    });

    test('5 wrong tries lock the code even for the right one', () {
      final c = code.issue('a@x.com');
      final bad = c == '111111' ? '222222' : '111111';
      for (var i = 0; i < 5; i++) {
        expect(code.check('a@x.com', bad), VerificationResult.wrong);
      }
      expect(code.check('a@x.com', c), VerificationResult.tooManyAttempts);
    });

    test('a new code replaces the old one and resets attempts', () {
      final first = code.issue('a@x.com');
      code.check('a@x.com', 'x');
      final second = code.issue('a@x.com');
      expect(code.check('a@x.com', second), VerificationResult.ok);
      expect(first.length, 6);
    });

    test('another address or nothing issued is none', () {
      expect(code.check('a@x.com', '123456'), VerificationResult.none);
      final c = code.issue('a@x.com');
      expect(code.check('b@x.com', c), VerificationResult.none);
    });
  });

  group('VerifyEmail with fake IMAP and SMTP (FR-03-03)', () {
    late FakeImap imap;
    late FakeSmtp smtp;
    late MemSecure secure;
    late TestEnv env;
    late EmailSettingsStore settings;
    late VerifyEmail verify;

    setUp(() {
      env = TestEnv();
      imap = FakeImap();
      smtp = FakeSmtp();
      secure = MemSecure();
      settings = EmailSettingsStore(SettingsKeyValueStore(env.settings));
      verify = VerifyEmail(
        imap: imap,
        sender: smtp,
        manage: ManageEmailAccount(
          imap: imap,
          settings: settings,
          credentials: SecureEmailCredentialStore(secure),
        ),
      );
    });
    tearDown(() => env.close());

    test('code is mailed to the same address with the same login', () async {
      await verify.signInAndSendCode(
        EmailAccount.forAddress('Me@Gmail.com'),
        'abcd efgh',
      );
      expect(imap.tests, 1);
      expect(smtp.lastTo, 'me@gmail.com');
      expect(smtp.lastPassword, 'abcdefgh');
      expect(smtp.lastSubject, startsWith('DhanKosh verification code: '));
      expect(await settings.accounts(), isEmpty); // nothing saved yet
      expect(secure.map, isEmpty);
    });

    test('right code saves the mailbox and its secret', () async {
      await verify.signInAndSendCode(
        EmailAccount.forAddress('me@gmail.com'),
        'abcdefgh',
      );
      expect(await verify.verify('000000'), VerificationResult.wrong);
      expect(await settings.accounts(), isEmpty);
      expect(await verify.verify(smtp.lastCode), VerificationResult.ok);
      expect((await settings.accounts()).single.address, 'me@gmail.com');
      expect(secure.map['email_app_password:me@gmail.com'], 'abcdefgh');
      expect(verify.pending, isFalse);
    });

    test('refused login sends no code', () async {
      imap.error = const AuthFailure('x');
      await expectLater(
        verify.signInAndSendCode(EmailAccount.forAddress('me@gmail.com'), 'p'),
        throwsA(isA<AuthFailure>()),
      );
      expect(smtp.sent, 0);
      expect(verify.pending, isFalse);
    });

    test('resend issues a new code; the old one stops working', () async {
      await verify.signInAndSendCode(
        EmailAccount.forAddress('me@gmail.com'),
        'abcdefgh',
      );
      final old = smtp.lastCode;
      await verify.resend();
      expect(smtp.sent, 2);
      if (smtp.lastCode != old) {
        expect(await verify.verify(old), VerificationResult.wrong);
      }
      expect(await verify.verify(smtp.lastCode), VerificationResult.ok);
    });

    test('smtp provider presets (FR-03-03)', () {
      final g = EmailAccount.forAddress('a@gmail.com');
      expect(
        [g.smtpHost, g.smtpPort, g.smtpSsl],
        ['smtp.gmail.com', 465, true],
      );
      final o = EmailAccount.forAddress('a@outlook.com');
      expect(
        [o.smtpHost, o.smtpPort, o.smtpSsl],
        ['smtp-mail.outlook.com', 587, false],
      );
      final c = EmailAccount.forAddress('a@corp.example');
      expect(c.smtpHost, 'smtp.corp.example');
    });
  });

  group('multi-mailbox sync (FR-03-06, FR-03-22)', () {
    late TestEnv env;
    late _PerAccountImap imap;
    late MemSecure secure;
    late EmailSettingsStore settings;
    late SyncEmail sync;
    late DateTime clock;
    const bank = 'HDFC Bank InstaAlerts <alerts@hdfcbank.net>';
    String body(String ref) => 'Dear Customer,\n\nRs.450.00 has been debited '
        'from account **1234 to VPA shop@icici DEMO STORE on 20-10-26.\n\n'
        'Your UPI transaction reference number is $ref.\n';
    RawEmail mail(String id, String ref, {int day = 20}) => RawEmail(
          id: id,
          from: bank,
          subject: 'Alert',
          receivedAt: DateTime(2026, 10, day, 11).millisecondsSinceEpoch,
          plain: body(ref),
        );

    setUp(() async {
      env = TestEnv();
      imap = _PerAccountImap();
      secure = MemSecure();
      settings = EmailSettingsStore(SettingsKeyValueStore(env.settings));
      final creds = SecureEmailCredentialStore(secure);
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
      final manage = ManageEmailAccount(
        imap: imap,
        settings: settings,
        credentials: creds,
      );
      await manage.save(EmailAccount.forAddress('one@gmail.com'), 'pw one');
      await manage.save(EmailAccount.forAddress('two@yahoo.com'), 'pw two');
      imap.byAddress['one@gmail.com'] = [mail('imap:<1@x>', '000000000001')];
      imap.byAddress['two@yahoo.com'] = [mail('imap:<2@x>', '000000000002')];
    });
    tearDown(() => env.close());

    test('every enabled mailbox is read and the counts are summed', () async {
      final r = await sync();
      expect(imap.asked, ['one@gmail.com', 'two@yahoo.com']);
      expect(r.emails, 2);
      expect(r.inserted, 2);
      expect(await env.count('transactions'), 2);
      expect(secure.map['email_app_password:one@gmail.com'], 'pwone');
      expect(secure.map['email_app_password:two@yahoo.com'], 'pwtwo');
    });

    test('each mailbox has its own cursor', () async {
      await sync();
      clock = clock.add(const Duration(days: 2));
      await sync();
      expect(
        await settings.lastSyncAt('one@gmail.com'),
        clock.millisecondsSinceEpoch,
      );
      // A third mailbox starts with a full read while the others go on.
      await ManageEmailAccount(
        imap: imap,
        settings: settings,
        credentials: SecureEmailCredentialStore(secure),
      ).save(EmailAccount.forAddress('three@gmail.com'), 'pw');
      clock = clock.add(const Duration(days: 1));
      final r = await sync();
      expect(r.mode, 'full');
      expect(
        imap.since['three@gmail.com'],
        clock.subtract(const Duration(days: 90)),
      );
      // Mailbox one was last read two days before the third sync, less the
      // one-day overlap.
      expect(
        imap.since['one@gmail.com'],
        clock.subtract(const Duration(days: 2)),
      );
    });

    test('a failing mailbox does not stop the others (FR-03-18)', () async {
      imap.errors['one@gmail.com'] = const AuthFailure('x');
      final r = await sync();
      expect(r.error, 'auth');
      expect(r.inserted, 1);
      expect(await settings.needsReauth('one@gmail.com'), isTrue);
      expect(await settings.needsReauth('two@yahoo.com'), isFalse);
      expect(await settings.lastSyncAt('one@gmail.com'), 0);
      expect(await settings.lastSyncAt('two@yahoo.com'), isPositive);
    });

    test('network failure of one is retryable for the run', () async {
      imap.errors['two@yahoo.com'] = const NetworkFailure('x');
      final r = await sync();
      expect(r.retryable, isTrue);
      expect(r.inserted, 1);
    });

    test('a switched-off mailbox is skipped; none on = not connected',
        () async {
      await settings.setEnabled('two@yahoo.com', enabled: false);
      await sync();
      expect(imap.asked, ['one@gmail.com']);
      await settings.setEnabled('one@gmail.com', enabled: false);
      expect((await sync()).error, 'not_connected');
    });

    test('removing a mailbox forgets only that one', () async {
      await ManageEmailAccount(
        imap: imap,
        settings: settings,
        credentials: SecureEmailCredentialStore(secure),
      ).disconnect('one@gmail.com');
      expect((await settings.accounts()).map((a) => a.address), [
        'two@yahoo.com',
      ]);
      expect(secure.map['email_app_password:one@gmail.com'], '');
      expect(secure.map['email_app_password:two@yahoo.com'], 'pwtwo');
    });

    test('switched-off default senders are not read (FR-26-31)', () async {
      await settings.saveRemovedDefaultSenders({'hdfcbank.net'});
      final r = await sync();
      expect(r.emails, 0);
      await settings.saveRemovedDefaultSenders({});
      expect((await sync()).emails, 2);
    });
  });
}

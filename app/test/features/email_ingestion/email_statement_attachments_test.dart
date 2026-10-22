import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart' as em;
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/email_ingestion/data/email_settings_store.dart';
import 'package:hisaab/features/email_ingestion/data/enough_mail_imap_client.dart';
import 'package:hisaab/features/email_ingestion/data/processed_email_repository_impl.dart';
import 'package:hisaab/features/email_ingestion/data/secure_email_credential_store.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';
import 'package:hisaab/features/email_ingestion/domain/statement_attachments.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/manage_email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/sync_email.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart'
    show IngestOutcome;

import '../../support/email_fakes.dart';
import '../../support/pipeline_fakes.dart';
import '../../support/test_env.dart';

void main() {
  // FR-03-16: attachment selection.
  test('only statement files within the size cap are accepted', () {
    expect(StatementAttachments.accepts(name: 'a.PDF'), isTrue);
    expect(StatementAttachments.accepts(name: 'a.xlsx'), isTrue);
    expect(StatementAttachments.accepts(mime: 'text/csv'), isTrue);
    expect(StatementAttachments.accepts(name: 'a.png'), isFalse);
    expect(
      StatementAttachments.accepts(
        name: 'a.pdf',
        size: StatementAttachments.maxBytes + 1,
      ),
      isFalse,
    );
    expect(
      StatementAttachments.nameOf(null, 'application/pdf'),
      'statement.pdf',
    );
  });

  test('enough_mail message yields its PDF attachment only', () {
    final pdf = base64.encode([0x25, 0x50, 0x44, 0x46, 1, 2, 3]);
    final raw = [
      'From: alerts@hdfcbank.net',
      'Subject: Statement',
      'MIME-Version: 1.0',
      'Content-Type: multipart/mixed; boundary="b"',
      '',
      '--b',
      'Content-Type: text/plain',
      '',
      'Hello',
      '--b',
      'Content-Type: application/pdf; name="stmt.pdf"',
      'Content-Disposition: attachment; filename="stmt.pdf"',
      'Content-Transfer-Encoding: base64',
      '',
      pdf,
      '--b',
      'Content-Type: image/png; name="x.png"',
      'Content-Disposition: attachment; filename="x.png"',
      'Content-Transfer-Encoding: base64',
      '',
      base64.encode([1, 2, 3]),
      '--b--',
      '',
    ].join('\r\n');
    final out =
        EnoughMailImapClient.attachmentsOf(em.MimeMessage.parseFromText(raw));
    expect(out, hasLength(1));
    expect(out.single.name, 'stmt.pdf');
    expect(out.single.bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });

  // FR-03-16, FR-03-14: sync hands files over, marks the mail, no repeat.
  test('sync passes attachments to the statement importer once', () async {
    final env = TestEnv();
    addTearDown(env.close);
    final imap = FakeImap();
    final kv = SettingsKeyValueStore(env.settings);
    final settings = EmailSettingsStore(kv);
    final creds = SecureEmailCredentialStore(MemSecure());
    final calls = <String>[];
    final sync = SyncEmail(
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
          IngestOutcome.rejected,
      ingestStatement: ({
        required sender,
        required subject,
        required emailText,
        required receivedAt,
        required messageId,
        required index,
        required fileName,
        required bytes,
      }) async {
        calls.add('$messageId#$index:$fileName');
        return StatementFileOutcome.imported;
      },
      now: () => DateTime(2026, 10, 21, 9),
    );
    await ManageEmailAccount(imap: imap, settings: settings, credentials: creds)
        .save(EmailAccount.forAddress('Me@Gmail.com'), 'abcd efgh ijkl mnop');
    imap.mails = [
      RawEmail(
        id: 'imap:<s@x>',
        from: 'HDFC Bank <alerts@hdfcbank.net>',
        subject: 'Your account statement',
        receivedAt: DateTime(2026, 10, 20).millisecondsSinceEpoch,
        plain: 'See attached',
        attachments: [
          EmailAttachment(name: 'st.pdf', bytes: Uint8List.fromList([1, 2])),
        ],
      ),
    ];
    final r = await sync();
    expect(r.statements, 1);
    expect(calls, ['imap:<s@x>#0:st.pdf']);
    final again = await sync();
    expect(again.skipped, 1);
    expect(calls, hasLength(1));
  });
}

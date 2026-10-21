import 'dart:async';

import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/email_ingestion/data/email_settings_store.dart';
import 'package:hisaab/features/email_ingestion/data/enough_mail_imap_client.dart';
import 'package:hisaab/features/email_ingestion/data/processed_email_repository_impl.dart';
import 'package:hisaab/features/email_ingestion/data/secure_email_credential_store.dart';
import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/email_sync_runner.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/manage_email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/sync_email.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:parser_core/parser_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'email_providers.g.dart';

// Phase 2 wiring: email -> parser_core -> ledger (F-03).

/// IMAP over enough_mail; override in tests.
@Riverpod(keepAlive: true)
ImapClient imapClient(Ref ref) => EnoughMailImapClient();

/// Non-secret email settings and sync cursor.
@Riverpod(keepAlive: true)
EmailSettingsRepository emailSettingsRepository(Ref ref) =>
    EmailSettingsStore(ref.watch(keyValueStoreProvider));

/// App password in secure storage only.
@Riverpod(keepAlive: true)
EmailCredentialStore emailCredentialStore(Ref ref) =>
    SecureEmailCredentialStore(ref.watch(secureStoreProvider));

/// Processed message ids.
@Riverpod(keepAlive: true)
ProcessedEmailRepository processedEmailRepository(Ref ref) =>
    ProcessedEmailRepositoryImpl(ref.watch(appDatabaseProvider));

/// One email sync (F-03).
@Riverpod(keepAlive: true)
SyncEmail syncEmail(Ref ref) {
  final ingest = ref.watch(ingestMessageProvider);
  return SyncEmail(
    imap: ref.watch(imapClientProvider),
    settings: ref.watch(emailSettingsRepositoryProvider),
    credentials: ref.watch(emailCredentialStoreProvider),
    processed: ref.watch(processedEmailRepositoryProvider),
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
  );
}

/// Scheduler entry: `ref.read(emailSyncRunnerProvider).run()` (the nightly
/// job and Sync now). Never throws.
@Riverpod(keepAlive: true)
EmailSyncRunner emailSyncRunner(Ref ref) {
  final log = ref.watch(activityLoggerProvider);
  return EmailSyncRunner(
    ref.watch(syncEmailProvider),
    // FR-22-05: counts and error class only.
    onReport: (r, started) => unawaited(
      log.record(
        ActivityEntry(
          at: started,
          source: ActivitySource.imap,
          emails: r.emails,
          added: r.inserted,
          merged: r.merged,
          review: r.flagged,
          skipped: r.skipped,
          millis: r.millis,
          error: r.error,
        ),
      ),
    ),
  );
}

/// Connect, disconnect and sender edits.
@Riverpod(keepAlive: true)
ManageEmailAccount manageEmailAccount(Ref ref) => ManageEmailAccount(
      imap: ref.watch(imapClientProvider),
      settings: ref.watch(emailSettingsRepositoryProvider),
      credentials: ref.watch(emailCredentialStoreProvider),
    );

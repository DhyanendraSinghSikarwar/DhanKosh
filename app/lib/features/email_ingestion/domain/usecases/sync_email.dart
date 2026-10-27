import 'dart:typed_data';

import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/email_text.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_sync_report.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';
import 'package:hisaab/features/email_ingestion/domain/sender_whitelist.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart'
    show IngestOutcome;

/// Parses one email body and stores the transaction through the ledger.
/// Outcome of handing one emailed statement file over (FR-03-16).
enum StatementFileOutcome { imported, locked, skipped }

/// Hands an emailed statement file to the statement importer (FR-05-16).
typedef IngestStatementFile = Future<StatementFileOutcome> Function({
  required String sender,
  required String subject,
  required String emailText,
  required int receivedAt,
  required String messageId,
  required int index,
  required String fileName,
  required Uint8List bytes,
});

typedef IngestEmail = Future<IngestOutcome> Function({
  required String sender,
  required String body,
  required int receivedAt,
  required String messageId,
});

/// One email sync: fetch since the cursor, filter senders, skip processed
/// ids, ingest, mark processed, report counts (FR-03-09, FR-03-10,
/// FR-03-12, FR-03-14, FR-03-18, FR-03-20, FR-03-21).
///
/// Never logs or returns message content.
class SyncEmail {
  /// Creates the use case.
  SyncEmail({
    required ImapClient imap,
    required EmailSettingsRepository settings,
    required EmailCredentialStore credentials,
    required ProcessedEmailRepository processed,
    required IngestEmail ingest,
    IngestStatementFile? ingestStatement,
    DateTime Function()? now,
  })  : _imap = imap,
        _settings = settings,
        _credentials = credentials,
        _processed = processed,
        _ingest = ingest,
        _statement = ingestStatement,
        _now = now ?? DateTime.now;

  final ImapClient _imap;
  final EmailSettingsRepository _settings;
  final EmailCredentialStore _credentials;
  final ProcessedEmailRepository _processed;
  final IngestEmail _ingest;
  final IngestStatementFile? _statement;
  final DateTime Function() _now;

  static const _overlap = Duration(days: 1);

  /// Syncs every enabled mailbox in turn and returns one combined report;
  /// never throws (FR-03-06). A failing mailbox does not stop the others;
  /// the combined `error` is the first failure.
  Future<EmailSyncReport> call() async {
    final started = _now();
    int elapsed() => _now().difference(started).inMilliseconds;
    try {
      final accounts = [
        for (final a in await _settings.accounts())
          if (a.enabled) a,
      ];
      if (accounts.isEmpty) {
        return const EmailSyncReport.failed('not_connected');
      }
      final reports = <EmailSyncReport>[];
      for (final a in accounts) {
        reports.add(await _syncOne(a));
      }
      return EmailSyncReport.combine(reports, millis: elapsed());
    } on Object catch (e) {
      return EmailSyncReport.failed(
        e is Failure ? 'failed' : e.runtimeType.toString(),
        millis: elapsed(),
      );
    }
  }

  /// Runs a sync of one mailbox and always returns a report; never throws.
  Future<EmailSyncReport> _syncOne(EmailAccount account) async {
    final started = _now();
    int elapsed() => _now().difference(started).inMilliseconds;
    final address = account.address;
    try {
      final password = await _credentials.read(address);
      if (password == null || password.isEmpty) {
        await _settings.setNeedsReauth(address, value: true);
        return const EmailSyncReport.failed('auth');
      }
      final last = await _settings.lastSyncAt(address);
      final full = last <= 0;
      final since = full
          ? started.subtract(Duration(days: await _settings.lookbackDays()))
          : DateTime.fromMillisecondsSinceEpoch(last).subtract(_overlap);
      final whitelist = SenderWhitelist(
        custom: await _settings.customSenders(),
        removed: await _settings.removedDefaultSenders(),
      );

      final List<RawEmail> mails;
      try {
        mails = await _imap.fetchSince(
          account,
          password,
          since: since,
          accept: whitelist.allows,
        );
      } on AuthFailure {
        await _settings.setNeedsReauth(address, value: true);
        return EmailSyncReport.failed('auth', millis: elapsed());
      } on TlsFailure {
        return EmailSyncReport.failed('tls', millis: elapsed());
      } on NetworkFailure {
        return EmailSyncReport.failed('network', millis: elapsed());
      }
      return await _process(address, mails, full, started, elapsed);
    } on Object catch (e) {
      // Class name only: never the message, it may carry mail content.
      return EmailSyncReport.failed(
        e is Failure ? 'failed' : e.runtimeType.toString(),
        millis: elapsed(),
      );
    }
  }

  Future<EmailSyncReport> _process(
    String address,
    List<RawEmail> mails,
    bool full,
    DateTime started,
    int Function() elapsed,
  ) async {
    final seen = await _processed.processed(mails.map((m) => m.id));
    var emails = 0;
    var inserted = 0;
    var merged = 0;
    var flagged = 0;
    var skipped = 0;
    var failed = 0;
    var statements = 0;
    for (final m in mails) {
      if (seen.contains(m.id)) {
        skipped++;
        continue;
      }
      emails++;
      try {
        final text = EmailText.choose(m.plain, m.html);
        final outcome = await _ingest(
          sender: m.from,
          body: text,
          receivedAt: m.receivedAt,
          messageId: m.id,
        );
        // FR-03-16: statement files go to the statement importer; a file
        // already imported answers skipped, so a retry never repeats it.
        var fileCount = 0;
        final handler = _statement;
        if (handler != null) {
          for (var i = 0; i < m.attachments.length; i++) {
            final a = m.attachments[i];
            final r = await handler(
              sender: m.from,
              subject: m.subject,
              emailText: text,
              receivedAt: m.receivedAt,
              messageId: m.id,
              index: i,
              fileName: a.name,
              bytes: a.bytes,
            );
            if (r != StatementFileOutcome.skipped) fileCount++;
          }
        }
        statements += fileCount;
        switch (outcome) {
          case IngestOutcome.inserted:
            inserted++;
          case IngestOutcome.merged:
            merged++;
          case IngestOutcome.flagged:
            flagged++;
          case IngestOutcome.skipped || IngestOutcome.rejected:
            break;
        }
        await _processed.mark(
          m.id,
          outcome == IngestOutcome.rejected && fileCount == 0
              ? 'REJECTED'
              : 'PARSED',
          at: _now().millisecondsSinceEpoch,
        );
      } on Object {
        failed++; // not marked: read again next sync
      }
    }
    final report = EmailSyncReport(
      mode: full ? 'full' : 'incremental',
      emails: emails,
      parsed: inserted + merged + flagged,
      inserted: inserted,
      merged: merged,
      flagged: flagged,
      skipped: skipped,
      failed: failed,
      statements: statements,
      millis: elapsed(),
    );
    await _settings.setNeedsReauth(address, value: false);
    // A failed message keeps the cursor so it is retried (overlap window).
    if (failed == 0) {
      await _settings.saveSync(
        address,
        at: started.millisecondsSinceEpoch,
        report: report.summary,
      );
    } else {
      await _settings.saveReport(address, report.summary);
    }
    return report;
  }
}

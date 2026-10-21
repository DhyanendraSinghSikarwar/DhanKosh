import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/email_text.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_sync_report.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';
import 'package:hisaab/features/email_ingestion/domain/sender_whitelist.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart'
    show IngestOutcome;

/// Parses one email body and stores the transaction through the ledger.
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
    DateTime Function()? now,
  })  : _imap = imap,
        _settings = settings,
        _credentials = credentials,
        _processed = processed,
        _ingest = ingest,
        _now = now ?? DateTime.now;

  final ImapClient _imap;
  final EmailSettingsRepository _settings;
  final EmailCredentialStore _credentials;
  final ProcessedEmailRepository _processed;
  final IngestEmail _ingest;
  final DateTime Function() _now;

  static const _overlap = Duration(days: 1);

  /// Runs a sync and always returns a report; never throws.
  Future<EmailSyncReport> call() async {
    final started = _now();
    int elapsed() => _now().difference(started).inMilliseconds;
    try {
      final account = await _settings.account();
      if (account == null) return const EmailSyncReport.failed('not_connected');
      final password = await _credentials.read();
      if (password == null || password.isEmpty) {
        await _settings.setNeedsReauth(value: true);
        return const EmailSyncReport.failed('auth');
      }
      final last = await _settings.lastSyncAt();
      final full = last <= 0;
      final since = full
          ? started.subtract(Duration(days: await _settings.lookbackDays()))
          : DateTime.fromMillisecondsSinceEpoch(last).subtract(_overlap);
      final whitelist =
          SenderWhitelist(custom: await _settings.customSenders());

      final List<RawEmail> mails;
      try {
        mails = await _imap.fetchSince(
          account,
          password,
          since: since,
          accept: whitelist.allows,
        );
      } on AuthFailure {
        await _settings.setNeedsReauth(value: true);
        return EmailSyncReport.failed('auth', millis: elapsed());
      } on TlsFailure {
        return EmailSyncReport.failed('tls', millis: elapsed());
      } on NetworkFailure {
        return EmailSyncReport.failed('network', millis: elapsed());
      }
      return await _process(mails, full, started, elapsed);
    } on Object catch (e) {
      // Class name only: never the message, it may carry mail content.
      return EmailSyncReport.failed(
        e is Failure ? 'failed' : e.runtimeType.toString(),
        millis: elapsed(),
      );
    }
  }

  Future<EmailSyncReport> _process(
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
    for (final m in mails) {
      if (seen.contains(m.id)) {
        skipped++;
        continue;
      }
      emails++;
      try {
        final outcome = await _ingest(
          sender: m.from,
          body: EmailText.choose(m.plain, m.html),
          receivedAt: m.receivedAt,
          messageId: m.id,
        );
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
          outcome == IngestOutcome.rejected ? 'REJECTED' : 'PARSED',
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
      millis: elapsed(),
    );
    await _settings.setNeedsReauth(value: false);
    // A failed message keeps the cursor so it is retried (overlap window).
    if (failed == 0) {
      await _settings.saveSync(
        at: started.millisecondsSinceEpoch,
        report: report.summary,
      );
    } else {
      await _settings.saveReport(report.summary);
    }
    return report;
  }
}

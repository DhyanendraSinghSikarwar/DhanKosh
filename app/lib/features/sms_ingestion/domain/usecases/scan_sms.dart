import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';

/// Parses and stores one message; the caller wires parser + ledger.
typedef SmsIngest = Future<IngestOutcome> Function(InboxSms sms);

/// Inbox scan (FR-02-08..FR-02-12, FR-02-20). Pure orchestration.
class ScanSms {
  /// Creates the use case.
  ScanSms({
    required SmsInboxSource inbox,
    required SmsSettingsRepository settings,
    required bool Function(String sender) accept,
    required SmsIngest ingest,
    DateTime Function() now = DateTime.now,
    Future<void> Function(String message)? recordActivity,
    void Function(SmsScanProgress progress)? onProgress,
    this.batchSize = 500,
  })  : _inbox = inbox,
        _settings = settings,
        _accept = accept,
        _ingest = ingest,
        _now = now,
        _recordActivity = recordActivity,
        _onProgress = onProgress;

  final SmsInboxSource _inbox;
  final SmsSettingsRepository _settings;
  final bool Function(String) _accept;
  final SmsIngest _ingest;
  final DateTime Function() _now;
  final Future<void> Function(String)? _recordActivity;
  final void Function(SmsScanProgress)? _onProgress;

  /// Accepted messages per batch.
  final int batchSize;

  /// Epoch ms to read from (section 10 window rules).
  static int windowStart({
    required SmsScanRequest request,
    required int cursor,
    required int nowMs,
    required int lookbackDays,
  }) {
    const day = Duration.millisecondsPerDay;
    int lookback() => nowMs - lookbackDays * day;
    if (request.full) return lookback();
    if (request.recentDays > 0) {
      final recent = nowMs - request.recentDays * day;
      // A never-scanned inbox (cursor 0) uses the recent window, not epoch 0.
      return cursor <= 0 ? recent : (cursor < recent ? cursor : recent);
    }
    return cursor <= 0 ? lookback() : cursor;
  }

  /// Runs the scan; never throws for permission or ingest errors.
  Future<SmsScanResult> call(SmsScanRequest request) async {
    final started = _now();
    final settings = await _settings.read();
    final nowMs = started.millisecondsSinceEpoch;
    final since = windowStart(
      request: request,
      cursor: settings.cursor,
      nowMs: nowMs,
      lookbackDays: settings.lookbackDays,
    );
    var bank = 0;
    var inserted = 0;
    var merged = 0;
    var flagged = 0;
    var skipped = 0;
    var checked = 0;
    var cursor = settings.cursor;
    String? error;
    try {
      final stats = await _inbox.readBatches(
        since: since,
        batchSize: batchSize,
        accept: _accept,
        onBatch: (batch) async {
          for (final sms in batch) {
            bank++;
            switch (await _ingest(sms)) {
              case IngestOutcome.inserted:
                inserted++;
              case IngestOutcome.merged:
                merged++;
              case IngestOutcome.flagged:
                flagged++;
              case IngestOutcome.skipped:
                skipped++;
              case IngestOutcome.rejected:
                break;
            }
            if (sms.receivedAt > cursor) cursor = sms.receivedAt;
          }
          _onProgress?.call(
            SmsScanProgress(scanned: bank, found: inserted + merged + flagged),
          );
        },
      );
      checked = stats.examined;
      if (stats.lastTimestamp > cursor) cursor = stats.lastTimestamp;
    } on PermissionFailure {
      error = 'permission';
    } on Object catch (e) {
      error = e.runtimeType.toString();
    }
    if (cursor > nowMs) cursor = nowMs;
    final millis = _now().difference(started).inMilliseconds;
    if (error == 'permission') {
      await _recordActivity?.call('SMS scan failed: permission');
      return SmsScanResult.failed('permission', settings.cursor);
    }
    final summary = SmsScanResult.formatSummary(
      checked: checked,
      bankMessages: bank,
      inserted: inserted,
      merged: merged,
      flagged: flagged,
      millis: millis,
    );
    await _settings.saveScan(
      cursor: cursor,
      lastScanAt: nowMs,
      lastResult: error ?? summary,
    );
    // Counts and error class only, never message text (FR-02-19).
    await _recordActivity
        ?.call(error == null ? summary : 'SMS scan error: $error');
    return SmsScanResult(
      checked: checked,
      bankMessages: bank,
      parsed: inserted + merged + flagged,
      inserted: inserted,
      merged: merged,
      flagged: flagged,
      skipped: skipped,
      millis: millis,
      cursor: cursor,
      summary: summary,
      error: error,
    );
  }
}

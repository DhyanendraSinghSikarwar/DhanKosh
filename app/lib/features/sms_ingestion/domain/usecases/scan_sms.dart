import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/activity_log/domain/activity_logger.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/activity_log/domain/inbox_logic.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

/// Parses and stores one message; the caller wires parser + ledger.
typedef SmsIngest = Future<IngestOutcome> Function(InboxSms sms);

/// Parses a whole batch (off the UI isolate) and stores it in order; one
/// outcome per message (FR-02-10).
typedef SmsBatchIngest = Future<List<IngestOutcome>> Function(
  List<InboxSms> batch,
);

/// Inbox scan (FR-02-08..FR-02-12, FR-02-20). Pure orchestration.
class ScanSms {
  /// Creates the use case.
  ScanSms({
    required SmsInboxSource inbox,
    required SmsSettingsRepository settings,
    required bool Function(String sender) accept,
    required SmsIngest ingest,
    SmsBatchIngest? ingestBatch,
    Future<void> Function()? prepare,
    DateTime Function() now = DateTime.now,
    Future<void> Function(String message)? recordActivity,
    ActivityLogger? activity,
    void Function(SmsScanProgress progress)? onProgress,
    this.batchSize = 500,
    AppLogger? log,
  })  : _log = log,
        _inbox = inbox,
        _settings = settings,
        _accept = accept,
        _ingest = ingest,
        _ingestBatch = ingestBatch,
        _prepare = prepare,
        _now = now,
        _recordActivity = recordActivity,
        _activity = activity,
        _onProgress = onProgress;

  final SmsInboxSource _inbox;
  final SmsSettingsRepository _settings;
  final bool Function(String) _accept;
  final SmsIngest _ingest;
  final SmsBatchIngest? _ingestBatch;
  final Future<void> Function()? _prepare;
  final DateTime Function() _now;
  final Future<void> Function(String)? _recordActivity;
  final ActivityLogger? _activity;
  final void Function(SmsScanProgress)? _onProgress;
  final AppLogger? _log;

  AppLogger get _logger => _log ?? AppLog.instance;

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
    await _prepare?.call();
    final settings = await _settings.read();
    final nowMs = started.millisecondsSinceEpoch;
    final since = windowStart(
      request: request,
      cursor: settings.cursor,
      nowMs: nowMs,
      lookbackDays: settings.lookbackDays,
    );
    // FR-35-20: counts and codes only, never message text.
    _logger.info(
      LogCategory.sms,
      'scan.start',
      fields: {
        'full': request.full,
        'recent_days': request.recentDays,
        'cursor_set': settings.cursor > 0,
      },
    );
    var bank = 0;
    var inserted = 0;
    var merged = 0;
    var flagged = 0;
    var skipped = 0;
    var checked = 0;
    final rejectedSenders = <String>[];
    var cursor = settings.cursor;
    String? error;
    try {
      final stats = await _inbox.readBatches(
        since: since,
        batchSize: batchSize,
        accept: _accept,
        onBatch: (batch) async {
          final outcomes = _ingestBatch != null
              ? await _ingestBatch(batch)
              : [for (final sms in batch) await _ingest(sms)];
          for (var i = 0; i < batch.length; i++) {
            bank++;
            switch (outcomes[i]) {
              case IngestOutcome.inserted:
                inserted++;
              case IngestOutcome.merged:
                merged++;
              case IngestOutcome.flagged:
                flagged++;
              case IngestOutcome.skipped:
                skipped++;
              case IngestOutcome.rejected:
                rejectedSenders.add(batch[i].sender);
            }
            if (batch[i].receivedAt > cursor) cursor = batch[i].receivedAt;
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
    // FR-22-01, FR-22-03: counts and error class only.
    await _activity?.record(
      ActivityEntry(
        at: started,
        source: ActivitySource.smsScan,
        read: error == 'permission' ? 0 : checked,
        relevant: error == 'permission' ? 0 : bank,
        added: inserted,
        merged: merged,
        review: flagged,
        skipped: skipped,
        millis: millis,
        error: error,
      ),
    );
    if (rejectedSenders.isNotEmpty) {
      // FR-22-15: count and sender code only, never body or amounts.
      await _activity?.record(
        ActivityEntry(
          at: started,
          source: ActivitySource.problems,
          read: rejectedSenders.length,
          note: InboxLogic.topSenderCode(rejectedSenders),
        ),
      );
    }
    final fields = <String, Object?>{
      'read': checked,
      'bank': bank,
      'added': inserted,
      'merged': merged,
      'review': flagged,
      'skipped': skipped,
      'ms': millis,
    };
    if (error != null) {
      _logger.warn(
        LogCategory.sms,
        'scan.failed',
        fields: {...fields, 'error': error},
      );
    } else {
      _logger.info(LogCategory.sms, 'scan.done', fields: fields);
    }
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

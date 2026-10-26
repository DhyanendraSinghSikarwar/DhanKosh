import 'package:hisaab/features/activity_log/domain/activity_logger.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

/// Ingests live messages (FR-02-05, FR-02-07, FR-02-02).
class HandleLiveSms {
  /// Creates the use case.
  const HandleLiveSms({
    required SmsSettingsRepository settings,
    required bool Function(String sender) accept,
    required SmsIngest ingest,
    ActivityLogger? activity,
    AppLogger? log,
  })  : _log = log,
        _settings = settings,
        _activity = activity,
        _accept = accept,
        _ingest = ingest;

  final SmsSettingsRepository _settings;
  final bool Function(String) _accept;
  final SmsIngest _ingest;
  final ActivityLogger? _activity;
  final AppLogger? _log;

  /// Returns null when paused or the sender is not accepted (no ingest, no
  /// activity), otherwise the ingest outcome.
  Future<IngestOutcome?> call(InboxSms sms) async {
    final log = _log ?? AppLog.instance;
    if (!(await _settings.read()).enabled) {
      log.debug(LogCategory.sms, 'live.ignored', fields: {'why': 'paused'});
      return null;
    }
    if (!_accept(sms.sender)) {
      log.debug(LogCategory.sms, 'live.ignored', fields: {'why': 'sender'});
      return null;
    }
    final started = DateTime.now();
    String? error;
    IngestOutcome? outcome;
    try {
      outcome = await _ingest(sms);
    } on Object catch (e) {
      error = e.runtimeType.toString();
      log.error(LogCategory.sms, 'live.failed', fields: errorFields(e));
      rethrow;
    } finally {
      if (error == null) {
        log.info(
          LogCategory.sms,
          'live.handled',
          fields: {'outcome': outcome?.name},
        );
      }
      // FR-22-01: one live entry per message, counts only (coalesced later).
      await _activity?.record(
        ActivityEntry(
          at: started,
          source: ActivitySource.smsLive,
          read: 1,
          relevant: 1,
          added: outcome == IngestOutcome.inserted ? 1 : 0,
          merged: outcome == IngestOutcome.merged ? 1 : 0,
          review: outcome == IngestOutcome.flagged ? 1 : 0,
          skipped: outcome == IngestOutcome.skipped ? 1 : 0,
          millis: DateTime.now().difference(started).inMilliseconds,
          error: error,
        ),
      );
    }
    return outcome;
  }
}

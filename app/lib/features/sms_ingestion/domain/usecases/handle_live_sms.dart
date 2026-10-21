import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';

/// Ingests live messages (FR-02-05, FR-02-07, FR-02-02).
class HandleLiveSms {
  /// Creates the use case.
  const HandleLiveSms({
    required SmsSettingsRepository settings,
    required bool Function(String sender) accept,
    required SmsIngest ingest,
  })  : _settings = settings,
        _accept = accept,
        _ingest = ingest;

  final SmsSettingsRepository _settings;
  final bool Function(String) _accept;
  final SmsIngest _ingest;

  /// Returns null when paused or the sender is not accepted (no ingest, no
  /// activity), otherwise the ingest outcome.
  Future<IngestOutcome?> call(InboxSms sms) async {
    if (!(await _settings.read()).enabled) return null;
    if (!_accept(sms.sender)) return null;
    return await _ingest(sms);
  }
}

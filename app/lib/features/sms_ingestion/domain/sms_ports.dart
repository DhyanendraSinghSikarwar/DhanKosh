import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';

/// What an inbox read covered.
class SmsReadStats {
  /// Creates stats.
  const SmsReadStats({required this.examined, required this.lastTimestamp});

  /// Rows examined, accepted or not.
  final int examined;

  /// Arrival time of the last row examined; 0 when none.
  final int lastTimestamp;
}

/// Reads the inbox in batches. Throws `PermissionFailure` without READ_SMS.
abstract interface class SmsInboxSource {
  /// Reads rows with `date > since` oldest first. Rows failing [accept] are
  /// counted but never passed on. Each [onBatch] gets at most [batchSize]
  /// accepted messages.
  Future<SmsReadStats> readBatches({
    required int since,
    required int batchSize,
    required bool Function(String sender) accept,
    required Future<void> Function(List<InboxSms> batch) onBatch,
  });
}

/// Live messages from the receiver.
abstract interface class SmsLiveSource {
  /// Messages arriving while the engine runs.
  Stream<InboxSms> get live;

  /// Messages queued natively while Dart was not listening; clears the queue.
  Future<List<InboxSms>> drainPending();

  /// Pushes pause flag and sender regex to the native receiver.
  Future<void> configure({
    required bool enabled,
    required String senderPattern,
  });
}

/// Persistence for [SmsSettings].
abstract interface class SmsSettingsRepository {
  /// Current settings.
  Future<SmsSettings> read();

  /// Pause or resume live reading.
  Future<void> setEnabled({required bool enabled});

  /// Saves scan state; the cursor never moves backwards (FR-02-08).
  Future<void> saveScan({
    required int cursor,
    required int lastScanAt,
    required String lastResult,
  });

  /// Persists the Home-card dismissal.
  Future<void> setPromptDismissed({required bool dismissed});

  /// Sets the look-back window (7, 30, 90, 180, 365).
  Future<void> setLookbackDays(int days);
}

import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/handle_live_sms.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

/// Ingests the messages the native receiver queued while no Dart listener
/// was attached, e.g. in the headless engine (FR-02-01, AC-02-01).
class DrainPendingSms {
  /// Creates the use case.
  const DrainPendingSms({
    required SmsLiveSource live,
    required HandleLiveSms handle,
  })  : _live = live,
        _handle = handle;

  final SmsLiveSource _live;
  final HandleLiveSms _handle;

  /// Returns how many messages were ingested. One bad message never stops the
  /// rest; a message that fails here is recovered by the next 14-day scan.
  Future<int> call() async {
    var done = 0;
    final pending = await _live.drainPending();
    AppLog.instance.info(
      LogCategory.sms,
      'drain.start',
      fields: {'pending': pending.length},
    );
    var failed = 0;
    for (final m in pending) {
      try {
        if (await _handle(m) != null) done++;
      } on Object catch (e) {
        // Counts only, never the text (FR-02-19).
        failed++;
        AppLog.instance.error(
          LogCategory.sms,
          'drain.item_failed',
          fields: errorFields(e),
        );
      }
    }
    AppLog.instance.info(
      LogCategory.sms,
      'drain.done',
      fields: {'ingested': done, 'failed': failed},
    );
    return done;
  }
}

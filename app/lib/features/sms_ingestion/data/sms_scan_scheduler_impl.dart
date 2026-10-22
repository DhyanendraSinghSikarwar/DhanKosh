import 'package:hisaab/core/platform_channels/background_channel.dart';
import 'package:hisaab/core/platform_channels/background_tasks.dart';
import 'package:hisaab/features/sms_ingestion/domain/nightly_schedule.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';

/// [SmsScanScheduler] over native WorkManager (FR-02-14).
class SmsScanSchedulerImpl implements SmsScanScheduler {
  /// Creates the scheduler.
  const SmsScanSchedulerImpl(
    this._channel, {
    DateTime Function()? now,
    this.onPlanned,
  }) : _now = now ?? DateTime.now;

  final BackgroundChannel _channel;
  final DateTime Function() _now;

  /// Told the next planned run (null when cancelled) so the Activity log can
  /// show "Next scheduled sync" (FR-22-08).
  final Future<void> Function(DateTime? next)? onPlanned;

  @override
  Future<void> scheduleNightly() async {
    final delay = nextNightlyDelay(_now());
    await _channel.schedulePeriodic(
      uniqueName: BackgroundTasks.nightlyUnique,
      task: BackgroundTasks.smsNightly,
      intervalMinutes: Duration.minutesPerDay,
      initialDelayMinutes: delay.inMinutes,
    );
    await onPlanned?.call(_now().add(delay));
  }

  @override
  Future<void> cancelNightly() async {
    await _channel.cancel(BackgroundTasks.nightlyUnique);
    await onPlanned?.call(null);
  }
}

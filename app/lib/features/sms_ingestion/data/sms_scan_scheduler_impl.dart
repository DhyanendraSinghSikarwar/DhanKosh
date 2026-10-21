import 'package:hisaab/core/platform_channels/background_channel.dart';
import 'package:hisaab/core/platform_channels/background_tasks.dart';
import 'package:hisaab/features/sms_ingestion/domain/nightly_schedule.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';

/// [SmsScanScheduler] over native WorkManager (FR-02-14).
class SmsScanSchedulerImpl implements SmsScanScheduler {
  /// Creates the scheduler.
  const SmsScanSchedulerImpl(this._channel, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final BackgroundChannel _channel;
  final DateTime Function() _now;

  @override
  Future<void> scheduleNightly() => _channel.schedulePeriodic(
        uniqueName: BackgroundTasks.nightlyUnique,
        task: BackgroundTasks.smsNightly,
        intervalMinutes: Duration.minutesPerDay,
        initialDelayMinutes: nextNightlyDelay(_now()).inMinutes,
      );

  @override
  Future<void> cancelNightly() =>
      _channel.cancel(BackgroundTasks.nightlyUnique);
}

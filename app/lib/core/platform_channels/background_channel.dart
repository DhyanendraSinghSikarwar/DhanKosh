import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Typed wrapper for the `background` channel: schedules native WorkManager
/// jobs and, inside the headless engine, reports which task to run.
class BackgroundChannel extends ChannelBase {
  /// Creates the wrapper over the `background` channel.
  const BackgroundChannel() : super(_channel);

  static const MethodChannel _channel = MethodChannel(ChannelNames.background);

  /// Headless engine only: the task name this engine was started for.
  Future<String?> getTask() => invoke<String>('getTask');

  /// Headless engine only: tells native the task finished; [ok] false asks
  /// for a retry.
  Future<void> done({required bool ok}) => invoke<void>('done', {'ok': ok});

  /// Enqueues a one-off job under [uniqueName] that runs [task].
  Future<void> scheduleOneOff({
    required String uniqueName,
    required String task,
    bool replace = false,
  }) =>
      invoke<void>('scheduleOneOff', {
        'uniqueName': uniqueName,
        'task': task,
        'replace': replace,
      });

  /// Registers a periodic job (keeps an existing one with the same name).
  /// No network constraint.
  Future<void> schedulePeriodic({
    required String uniqueName,
    required String task,
    required int intervalMinutes,
    required int initialDelayMinutes,
    bool requiresBatteryNotLow = true,
  }) =>
      invoke<void>('schedulePeriodic', {
        'uniqueName': uniqueName,
        'task': task,
        'intervalMinutes': intervalMinutes,
        'initialDelayMinutes': initialDelayMinutes,
        'requiresBatteryNotLow': requiresBatteryNotLow,
      });

  /// Cancels the job registered under [uniqueName].
  Future<void> cancel(String uniqueName) =>
      invoke<void>('cancel', {'uniqueName': uniqueName});
}

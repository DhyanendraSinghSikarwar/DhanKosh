/// Names of background tasks and their unique work names (native side).
///
/// A task name selects the Dart handler in the headless engine; the unique
/// name keeps one pending job per purpose.
abstract final class BackgroundTasks {
  /// Drain the native live-SMS queue and ingest it (FR-02-01).
  static const smsDrain = 'sms.drain';

  /// Nightly 14-day inbox re-read (FR-02-14).
  static const smsNightly = 'sms.nightly';

  /// Alert check (budgets, bills, renewals; FR-21-13).
  static const alertsCheck = 'alerts.check';

  /// Unique work name for [smsDrain].
  static const smsDrainUnique = 'sms-live-drain';

  /// Unique work name for [smsNightly] (`nightly-sync` in the Kotlin app).
  static const nightlyUnique = 'nightly-sync';
}

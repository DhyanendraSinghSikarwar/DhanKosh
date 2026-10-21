import 'package:hisaab/features/email_ingestion/domain/entities/email_sync_report.dart';
import 'package:hisaab/features/email_ingestion/domain/usecases/sync_email.dart';

/// Entry point for schedulers (nightly job, Sync now). One run at a time;
/// never throws (FR-03-17, FR-03-18).
///
/// The scheduler maps the result: [EmailSyncReport.retryable] means ask for
/// a retry with backoff (up to 5 attempts); any other result is final.
class EmailSyncRunner {
  /// Creates the runner.
  EmailSyncRunner(this._sync, {this.onChanged, this.onReport});

  final SyncEmail _sync;

  /// Called after a run that added or merged transactions.
  final void Function()? onChanged;

  /// Called after every run with the report and its start (activity log,
  /// FR-22-05); must not throw.
  final void Function(EmailSyncReport report, DateTime startedAt)? onReport;

  Future<EmailSyncReport>? _running;

  /// Whether a run is in flight.
  bool get running => _running != null;

  /// Runs a sync; a call during a run joins that run.
  Future<EmailSyncReport> run() {
    final started = DateTime.now();
    return _running ??= _sync().then((r) {
      if (r.changed) onChanged?.call();
      try {
        onReport?.call(r, started);
      } on Object {
        // Logging never breaks a sync (FR-22-13).
      }
      return r;
    }).whenComplete(() => _running = null);
  }
}

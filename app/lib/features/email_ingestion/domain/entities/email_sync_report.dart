/// Result of one sync (FR-03-21). Counts only, never mail content.
class EmailSyncReport {
  /// Creates a report.
  const EmailSyncReport({
    required this.mode,
    this.emails = 0,
    this.parsed = 0,
    this.inserted = 0,
    this.merged = 0,
    this.flagged = 0,
    this.skipped = 0,
    this.failed = 0,
    this.statements = 0,
    this.millis = 0,
    this.error,
  });

  /// Report for a sync that could not run; [error] is a short code.
  const EmailSyncReport.failed(String error, {int millis = 0})
      : this(mode: 'failed', error: error, millis: millis);

  /// `full`, `incremental` or `failed`.
  final String mode;

  /// Allowed emails read.
  final int emails;

  /// Emails that produced a transaction.
  final int parsed;

  /// New transactions.
  final int inserted;

  /// Merged into an existing transaction (e.g. the SMS twin).
  final int merged;

  /// Saved but flagged for review.
  final int flagged;

  /// Already processed, skipped.
  final int skipped;

  /// Emails that threw while processing; retried next sync.
  final int failed;

  /// Emailed statement files imported or waiting for a password (FR-03-16).
  final int statements;

  /// Duration in ms.
  final int millis;

  /// `not_connected`, `auth`, `network`, `tls`, or null on success.
  final String? error;

  /// True on a clean run.
  bool get ok => error == null;

  /// Whether a retry may help (network only).
  bool get retryable => error == 'network';

  /// True when Home should refresh.
  bool get changed => inserted + merged + flagged + statements > 0;

  /// `"<mode>: N emails, M transactions (a new, b merged, c to review) in Xs"`
  String get summary => error != null
      ? switch (error) {
          'not_connected' => 'Email not connected',
          'auth' => 'Sign in again',
          'tls' => 'Secure connection failed',
          'network' => 'Could not reach the mail server',
          _ => 'Email sync failed',
        }
      : '$mode: $emails emails, $parsed transactions '
          '($inserted new, $merged merged, $flagged to review'
          '${statements > 0 ? ', $statements statements' : ''}) '
          'in ${(millis / 1000).toStringAsFixed(1)}s';
}

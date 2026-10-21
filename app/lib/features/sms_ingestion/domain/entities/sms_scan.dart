/// What to scan (FR-02-08).
class SmsScanRequest {
  /// Creates a request; default is incremental.
  const SmsScanRequest({this.full = false, this.recentDays = 0});

  /// Full re-read of the look-back window.
  const SmsScanRequest.full() : this(full: true);

  /// Re-read the last [days] days (never newer than the cursor).
  const SmsScanRequest.recent(int days) : this(recentDays: days);

  /// True for a full scan.
  final bool full;

  /// Recent window in days; 0 = off.
  final int recentDays;
}

/// Live progress (FR-02-15).
class SmsScanProgress {
  /// Creates progress counts.
  const SmsScanProgress({this.scanned = 0, this.found = 0});

  /// Bank messages read.
  final int scanned;

  /// Messages parsed into transactions.
  final int found;
}

/// Result of ingesting one message.
enum IngestOutcome {
  /// New transaction.
  inserted,

  /// Merged into an existing one.
  merged,

  /// Saved but flagged for review.
  flagged,

  /// Already processed (idempotent re-ingest, FR-02-20).
  skipped,

  /// Not a transaction (e.g. OTP); nothing stored.
  rejected,
}

/// Outcome of a scan (FR-02-11).
class SmsScanResult {
  /// Creates a result.
  const SmsScanResult({
    required this.checked,
    required this.bankMessages,
    required this.parsed,
    required this.inserted,
    required this.merged,
    required this.flagged,
    required this.skipped,
    required this.millis,
    required this.cursor,
    required this.summary,
    this.error,
  });

  /// Result for a scan that could not run (e.g. `permission`).
  factory SmsScanResult.failed(String error, int cursor) => SmsScanResult(
        checked: 0,
        bankMessages: 0,
        parsed: 0,
        inserted: 0,
        merged: 0,
        flagged: 0,
        skipped: 0,
        millis: 0,
        cursor: cursor,
        summary: error,
        error: error,
      );

  /// Exact summary text from section 10 of the feature memory.
  static String formatSummary({
    required int checked,
    required int bankMessages,
    required int inserted,
    required int merged,
    required int flagged,
    required int millis,
  }) =>
      '$checked SMS checked, $bankMessages from banks, $inserted new, '
      '$merged merged, $flagged to review '
      '(${(millis / 1000).toStringAsFixed(1)}s)';

  /// Inbox rows examined.
  final int checked;

  /// Rows accepted by the sender filter.
  final int bankMessages;

  /// Messages that produced a transaction (inserted + merged + flagged).
  final int parsed;

  /// New transactions.
  final int inserted;

  /// Merged transactions.
  final int merged;

  /// Flagged for review.
  final int flagged;

  /// Already processed.
  final int skipped;

  /// Duration in ms.
  final int millis;

  /// Stored cursor after the scan.
  final int cursor;

  /// Human summary.
  final String summary;

  /// `permission` or an exception class name; null on success.
  final String? error;

  /// True when Home should refresh (inserted + merged + flagged > 0).
  bool get changed => inserted + merged + flagged > 0;
}

/// Persisted SMS settings (FR-02-05, FR-02-17).
class SmsSettings {
  /// Creates settings with the documented defaults.
  const SmsSettings({
    this.enabled = true,
    this.cursor = 0,
    this.lastScanAt,
    this.lastResult,
    this.promptDismissed = false,
    this.lookbackDays = 90,
  });

  /// Live reading on.
  final bool enabled;

  /// Highest message time already read, epoch ms.
  final int cursor;

  /// Last scan time, epoch ms.
  final int? lastScanAt;

  /// Last summary text.
  final String? lastResult;

  /// Home card dismissed.
  final bool promptDismissed;

  /// 7, 30, 90, 180 or 365.
  final int lookbackDays;
}

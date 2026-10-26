/// Severity of a diagnostic entry (FR-35-02).
enum LogLevel {
  /// Verbose detail, off by default.
  debug,

  /// Normal events (default threshold).
  info,

  /// Recoverable problems.
  warn,

  /// Failures.
  error,
}

/// Where an entry comes from (FR-35-02). Closed set: no free text.
enum LogCategory {
  /// Bank SMS reading and live SMS.
  sms,

  /// Payment-app notifications.
  notifications,

  /// IMAP email sync.
  email,

  /// Statement import.
  statement,

  /// Ledger writes.
  ledger,

  /// Headless and scheduled tasks.
  background,

  /// Kotlin platform channels.
  channel,

  /// Database open and migration.
  db,

  /// Screens and lock events.
  ui,

  /// App start, resume, global errors.
  app,
}

/// One diagnostic line: time, level, category, short code, safe fields.
class LogEntry {
  /// Creates an entry (values are assumed sanitised).
  const LogEntry({
    required this.at,
    required this.level,
    required this.category,
    required this.code,
    this.fields = const {},
  });

  /// UTC time.
  final DateTime at;

  /// Severity.
  final LogLevel level;

  /// Source area.
  final LogCategory category;

  /// Short event code such as `scan.done`.
  final String code;

  /// Sanitised key to value pairs.
  final Map<String, String> fields;
}

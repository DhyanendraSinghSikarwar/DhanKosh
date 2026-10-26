/// Where a log entry came from (FR-22-01).
enum ActivitySource {
  /// Manual or scheduled inbox scan.
  smsScan('SMS_SCAN', 'SMS scan'),

  /// Live SMS broadcast.
  smsLive('SMS_LIVE', 'Live SMS'),

  /// Gmail sync.
  gmail('GMAIL', 'Gmail'),

  /// IMAP sync.
  imap('IMAP', 'IMAP'),

  /// Statements.
  statements('STATEMENTS', 'Statements'),

  /// Payment-app notifications.
  notifications('NOTIFICATIONS', 'Notifications'),

  /// Messages from bank-like senders that could not be read (FR-22-15).
  problems('PROBLEMS', 'Problems');

  const ActivitySource(this.code, this.label);

  /// Stored name.
  final String code;

  /// Display name.
  final String label;

  /// Decodes a stored [code]; null for unknown values.
  static ActivitySource? fromCode(String code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// One run of a sync path. Counts, error class and a generic reason only,
/// never message text (FR-22-01, FR-25-18).
class ActivityEntry {
  /// Creates an entry.
  const ActivityEntry({
    required this.at,
    required this.source,
    this.read = 0,
    this.relevant = 0,
    this.added = 0,
    this.merged = 0,
    this.review = 0,
    this.skipped = 0,
    this.emails = 0,
    this.statements = 0,
    this.locked = 0,
    this.millis = 0,
    this.error,
    this.runs = 1,
    this.note,
  });

  /// Run start.
  final DateTime at;

  /// Origin.
  final ActivitySource source;

  /// Messages looked at.
  final int read;

  /// Of [read], from banks or payment apps.
  final int relevant;

  /// Transactions inserted.
  final int added;

  /// Merged into an existing transaction.
  final int merged;

  /// Flagged for review.
  final int review;

  /// Duplicates already processed.
  final int skipped;

  /// Emails fetched.
  final int emails;

  /// Statements read.
  final int statements;

  /// Of those, still locked.
  final int locked;

  /// Duration in ms.
  final int millis;

  /// Error class name, never its message.
  final String? error;

  /// Coalesced runs.
  final int runs;

  /// Generic skip reason.
  final String? note;

  /// Coalescing merge for live sources (FR-22-04).
  ActivityEntry plus(ActivityEntry o) => ActivityEntry(
        at: at,
        source: source,
        read: read + o.read,
        relevant: relevant + o.relevant,
        added: added + o.added,
        merged: merged + o.merged,
        review: review + o.review,
        skipped: skipped + o.skipped,
        emails: emails,
        statements: statements,
        locked: locked,
        millis: millis + o.millis,
        error: o.error ?? error,
        runs: runs + o.runs,
        note: o.note ?? note,
      );
}

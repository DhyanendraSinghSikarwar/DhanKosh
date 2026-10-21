/// Reminder state of one card and due date (FR-21-11). Stages are
/// `DueStage` names (`days5`, `days2`, `dueDay`, `overdue`).
class CardReminderRecord {
  /// Creates a record.
  const CardReminderRecord({
    required this.cardId,
    required this.dueEpochDay,
    this.stagesSent = const {},
    this.paid = false,
    this.snoozedUntilEpochDay,
  });

  final int cardId;
  final int dueEpochDay;
  final Set<String> stagesSent;
  final bool paid;
  final int? snoozedUntilEpochDay;
}

/// Persists [CardReminderRecord]s; rows older than 120 days past due are
/// pruned on every write (FR-21-11).
abstract interface class CardReminderStateStore {
  /// Days kept after the due date.
  static const pruneDays = 120;

  /// The record, or null when none.
  Future<CardReminderRecord?> read(int cardId, int dueEpochDay);

  /// Stores [r] (replacing), then prunes against [todayEpochDay].
  Future<void> save(CardReminderRecord r, {required int todayEpochDay});

  /// Adds [stage] to the sent stages (creating the row).
  Future<void> markSent(
    int cardId,
    int dueEpochDay,
    String stage, {
    required int todayEpochDay,
  });

  /// "Mark paid" (FR-21-10).
  Future<void> markPaid(
    int cardId,
    int dueEpochDay, {
    required int todayEpochDay,
  });

  /// "Remind tomorrow" (FR-21-10).
  Future<void> snooze(
    int cardId,
    int dueEpochDay,
    int untilEpochDay, {
    required int todayEpochDay,
  });
}

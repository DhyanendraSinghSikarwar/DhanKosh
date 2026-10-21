import 'package:hisaab/features/credit_cards/domain/card_models.dart';

/// Reminder stage plan (FR-14-10).
abstract final class CardReminderPlan {
  /// No reminders more than this many days overdue.
  static const overdueWindow = 7;

  /// Stage to notify now, or null when paid, snoozed, never reached, already
  /// sent, or too late. Days are epoch days.
  static DueStage? next({
    required int today,
    required int due,
    required Set<DueStage> sent,
    bool paid = false,
    int? snoozedUntilDay,
  }) {
    if (paid) return null;
    if (snoozedUntilDay != null && snoozedUntilDay > today) return null;
    final days = due - today;
    if (days < -overdueWindow) return null;
    DueStage? stage;
    for (final s in DueStage.values) {
      if (days <= s.offsetDays &&
          (stage == null || s.offsetDays < stage.offsetDays)) {
        stage = s;
      }
    }
    if (stage == null || sent.contains(stage)) return null;
    return stage;
  }

  /// Stages to record when [stage] is sent: it and every less urgent one.
  static Set<DueStage> markSent(DueStage stage) => {
        for (final s in DueStage.values)
          if (s.offsetDays >= stage.offsetDays) s,
      };
}

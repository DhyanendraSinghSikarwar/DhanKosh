import 'package:hisaab/features/savings_goals/domain/goal.dart';

/// Progress of one goal (FR-36-03).
class GoalProgress {
  /// Creates progress.
  const GoalProgress({
    required this.goal,
    required this.savedMinor,
    required this.remainingMinor,
    required this.fraction,
    this.projectedDay,
    this.onTrack,
    this.requiredPerMonthMinor,
  });

  final Goal goal;
  final int savedMinor;
  final int remainingMinor;

  /// 0..1.
  final double fraction;

  /// Epoch day the goal is reached at the pace so far; null with no
  /// contributions.
  final int? projectedDay;

  /// Projected day is on or before the target day; null without a target
  /// day or projection.
  final bool? onTrack;

  /// Needed each month to reach the target day; null without a target day or
  /// when done.
  final int? requiredPerMonthMinor;

  /// Target reached.
  bool get done => remainingMinor == 0;
}

/// Goal maths, integer only (memory 36 section 10).
abstract final class GoalMath {
  /// The pace is measured over at least this many days, so one early
  /// deposit does not project an absurdly early finish.
  static const minPaceDays = 30;

  /// FR-36-03: progress of [g] from its [contributions] on [today].
  static GoalProgress progress(
    Goal g,
    List<GoalContribution> contributions,
    int today,
  ) {
    final mine = contributions.where((c) => c.goalId == g.id).toList();
    final saved = mine.fold<int>(0, (a, c) => a + c.amountMinor);
    final remaining = g.targetMinor > saved ? g.targetMinor - saved : 0;
    final fraction =
        g.targetMinor <= 0 ? 0.0 : (saved / g.targetMinor).clamp(0.0, 1.0);
    int? projected;
    if (remaining == 0) {
      projected = today;
    } else if (saved > 0 && mine.isNotEmpty) {
      final first = mine.map((c) => c.day).reduce((a, b) => a < b ? a : b);
      final elapsed = today - first + 1;
      final span = elapsed < minPaceDays ? minPaceDays : elapsed;
      // ceil(remaining * span / saved)
      final days = (remaining * span + saved - 1) ~/ saved;
      projected = today + days;
    }
    final td = g.targetDay;
    int? perMonth;
    if (td != null && remaining > 0) {
      final left = td - today;
      final months = left <= 0 ? 1 : (left + 29) ~/ 30;
      perMonth = (remaining + months - 1) ~/ months;
    }
    return GoalProgress(
      goal: g,
      savedMinor: saved,
      remainingMinor: remaining,
      fraction: fraction,
      projectedDay: projected,
      onTrack: (td != null && projected != null) ? projected <= td : null,
      requiredPerMonthMinor: perMonth,
    );
  }
}

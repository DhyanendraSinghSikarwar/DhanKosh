/// A savings goal (FR-36-01). Money in paise; days are IST epoch days.
class Goal {
  /// Creates a goal.
  const Goal({
    required this.id,
    required this.name,
    required this.targetMinor,
    required this.createdAt,
    this.targetDay,
  });

  final int id;
  final String name;
  final int targetMinor;

  /// Optional date to reach the target by.
  final int? targetDay;

  /// Epoch ms.
  final int createdAt;
}

/// A manual contribution to a goal (FR-36-02).
class GoalContribution {
  /// Creates a contribution.
  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.amountMinor,
    required this.day,
    this.note,
  });

  final int id;
  final int goalId;
  final int amountMinor;

  /// Epoch day (IST).
  final int day;
  final String? note;
}

/// Input for adding or editing a goal.
class GoalDraft {
  /// Creates a draft.
  const GoalDraft({
    required this.name,
    required this.targetMinor,
    this.targetDay,
  });

  final String name;
  final int targetMinor;
  final int? targetDay;

  /// Null when valid, else a short reason.
  String? validate() {
    if (name.trim().isEmpty) return 'Name required';
    if (targetMinor <= 0) return 'Target must be above 0';
    return null;
  }
}

/// Goals and contributions store (FR-36-01, FR-36-02). Tracking only: it
/// never touches the ledger.
abstract interface class GoalRepository {
  /// Goals, oldest first.
  Stream<List<Goal>> watchGoals();

  /// All contributions, oldest first.
  Stream<List<GoalContribution>> watchContributions();

  /// Adds a validated goal; returns its id.
  Future<int> addGoal(GoalDraft draft);

  /// Replaces goal [id].
  Future<void> updateGoal(int id, GoalDraft draft);

  /// Deletes goal [id] and its contributions.
  Future<void> deleteGoal(int id);

  /// Adds a contribution of [amountMinor] (> 0) on [day]; returns its id.
  Future<int> addContribution(
    int goalId,
    int amountMinor,
    int day, {
    String? note,
  });

  /// Deletes contribution [id].
  Future<void> deleteContribution(int id);
}

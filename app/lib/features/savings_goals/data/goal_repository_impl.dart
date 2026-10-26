import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/savings_goals/domain/goal.dart';

/// [GoalRepository] over `goals` and `goal_contributions`.
class GoalRepositoryImpl implements GoalRepository {
  /// Creates the repository; [now] is epoch ms.
  GoalRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  void _check(GoalDraft d) {
    final e = d.validate();
    if (e != null) throw ArgumentError(e);
  }

  @override
  Stream<List<Goal>> watchGoals() => (_db.select(_db.goals)
        ..orderBy([
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]))
      .watch()
      .map(
        (rows) => [
          for (final r in rows)
            Goal(
              id: r.id,
              name: r.name,
              targetMinor: r.targetMinor,
              targetDay: r.targetDay,
              createdAt: r.createdAt,
            ),
        ],
      );

  @override
  Stream<List<GoalContribution>> watchContributions() =>
      (_db.select(_db.goalContributions)
            ..orderBy([
              (t) => OrderingTerm.asc(t.day),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                GoalContribution(
                  id: r.id,
                  goalId: r.goalId,
                  amountMinor: r.amountMinor,
                  day: r.day,
                  note: r.note,
                ),
            ],
          );

  @override
  Future<int> addGoal(GoalDraft draft) async {
    _check(draft);
    final id = await _db.into(_db.goals).insert(
          GoalsCompanion.insert(
            name: draft.name.trim(),
            targetMinor: draft.targetMinor,
            targetDay: Value(draft.targetDay),
            createdAt: _now(),
          ),
        );
    return id;
  }

  @override
  Future<void> updateGoal(int id, GoalDraft draft) async {
    _check(draft);
    await (_db.update(_db.goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        name: Value(draft.name.trim()),
        targetMinor: Value(draft.targetMinor),
        targetDay: Value(draft.targetDay),
      ),
    );
  }

  @override
  Future<void> deleteGoal(int id) => _db.transaction(() async {
        await (_db.delete(_db.goalContributions)
              ..where((t) => t.goalId.equals(id)))
            .go();
        await (_db.delete(_db.goals)..where((t) => t.id.equals(id))).go();
      });

  @override
  Future<int> addContribution(
    int goalId,
    int amountMinor,
    int day, {
    String? note,
  }) async {
    if (amountMinor <= 0) throw ArgumentError('Amount must be above 0');
    final id = await _db.into(_db.goalContributions).insert(
          GoalContributionsCompanion.insert(
            goalId: goalId,
            amountMinor: amountMinor,
            day: day,
            note: Value(note),
            createdAt: _now(),
          ),
        );
    return id;
  }

  @override
  Future<void> deleteContribution(int id) =>
      (_db.delete(_db.goalContributions)..where((t) => t.id.equals(id))).go();
}

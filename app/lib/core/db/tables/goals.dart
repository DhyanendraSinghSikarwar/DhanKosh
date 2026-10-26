import 'package:drift/drift.dart';

/// Savings goals (FR-36-01). Tracking only.
@DataClassName('GoalRow')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get targetMinor => integer()();

  /// Epoch day (IST), optional.
  IntColumn get targetDay => integer().nullable()();
  IntColumn get createdAt => integer()();
}

/// Manual contributions to a goal (FR-36-02). Soft reference, deleted with
/// the goal by the repository.
@DataClassName('GoalContributionRow')
class GoalContributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer()();
  IntColumn get amountMinor => integer()();

  /// Epoch day (IST).
  IntColumn get day => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
}

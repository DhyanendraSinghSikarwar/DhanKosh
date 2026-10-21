import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';

/// User recurring items (F-12). Detected items are derived, not stored.
abstract interface class RecurringRepository {
  /// All user items, oldest first.
  Stream<List<RecurringItem>> watchAll();

  /// All user items.
  Future<List<RecurringItem>> all();

  /// Adds a validated [draft] (FR-12-03); returns the id. Throws
  /// [ArgumentError] when `draft.validate()` fails.
  Future<int> add(RecurringDraft draft);

  /// Replaces item [id] with [draft].
  Future<void> update(int id, RecurringDraft draft);

  /// Deletes item [id].
  Future<void> delete(int id);

  /// Items attached to [accountId] (account delete warning).
  Future<int> countForAccount(int accountId);
}

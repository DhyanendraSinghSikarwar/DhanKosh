import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';

/// Port the ingestion paths record through (FR-22-01). Implementations never
/// throw (FR-22-13).
abstract interface class ActivityLogger {
  /// Records one run.
  Future<void> record(ActivityEntry entry);
}

/// Stored log (FR-22-02).
abstract interface class ActivityLogRepository implements ActivityLogger {
  /// Newest first, at most [maxEntries].
  Stream<List<ActivityEntry>> watch();

  /// Removes every entry; transactions are untouched (FR-22-12).
  Future<void> clear();

  /// Kept entries.
  static const int maxEntries = 200;

  /// Live sources merge within this window (FR-22-04).
  static const int coalesceMs = 30 * 60 * 1000;
}

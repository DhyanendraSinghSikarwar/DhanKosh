import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/activity_log/domain/activity_logger.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';

/// Drift-backed log: coalescing and the 200-row cap run in one transaction
/// (FR-22-02, FR-22-04). Recording never throws (FR-22-13).
class ActivityLogRepositoryImpl implements ActivityLogRepository {
  /// Creates the repository over [_db].
  const ActivityLogRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<ActivityEntry>> watch() {
    final q = _db.select(_db.activityEntries)
      ..orderBy([
        (t) => OrderingTerm.desc(t.at),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(ActivityLogRepository.maxEntries);
    return q.watch().map(
          (rows) => [
            for (final r in rows)
              if (_decode(r) case final e?) e,
          ],
        );
  }

  @override
  Future<void> record(ActivityEntry e) async {
    try {
      await _db.transaction(() async {
        final head = await (_db.select(_db.activityEntries)
              ..orderBy([
                (t) => OrderingTerm.desc(t.at),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
        final live = e.source == ActivitySource.smsLive ||
            e.source == ActivitySource.notifications;
        final delta = head == null ? -1 : e.at.millisecondsSinceEpoch - head.at;
        final headEntry = head == null ? null : _decode(head);
        if (live &&
            head != null &&
            headEntry != null &&
            headEntry.source == e.source &&
            delta >= 0 &&
            delta <= ActivityLogRepository.coalesceMs) {
          final m = headEntry.plus(e);
          await (_db.update(_db.activityEntries)
                ..where((t) => t.id.equals(head.id)))
              .write(_companion(m));
        } else {
          await _db.into(_db.activityEntries).insert(_companion(e));
        }
        await _db.customStatement(
          'DELETE FROM activity_entries WHERE id NOT IN '
          '(SELECT id FROM activity_entries ORDER BY at DESC, id DESC '
          'LIMIT ${ActivityLogRepository.maxEntries})',
        );
      });
    } on Object {
      // FR-22-13: logging must never break a sync.
    }
  }

  @override
  Future<void> clear() => _db.delete(_db.activityEntries).go();

  static ActivityEntriesCompanion _companion(ActivityEntry e) =>
      ActivityEntriesCompanion.insert(
        at: e.at.millisecondsSinceEpoch,
        source: e.source.code,
        read: Value(e.read),
        relevant: Value(e.relevant),
        added: Value(e.added),
        merged: Value(e.merged),
        review: Value(e.review),
        skipped: Value(e.skipped),
        emails: Value(e.emails),
        statements: Value(e.statements),
        locked: Value(e.locked),
        millis: Value(e.millis),
        error: Value(e.error),
        runs: Value(e.runs),
        note: Value(e.note),
      );

  static ActivityEntry? _decode(ActivityRow r) {
    final s = ActivitySource.fromCode(r.source);
    if (s == null) return null;
    return ActivityEntry(
      at: DateTime.fromMillisecondsSinceEpoch(r.at),
      source: s,
      read: r.read,
      relevant: r.relevant,
      added: r.added,
      merged: r.merged,
      review: r.review,
      skipped: r.skipped,
      emails: r.emails,
      statements: r.statements,
      locked: r.locked,
      millis: r.millis,
      error: r.error,
      runs: r.runs,
      note: r.note,
    );
  }
}

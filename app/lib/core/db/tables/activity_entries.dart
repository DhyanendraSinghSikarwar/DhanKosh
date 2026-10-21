import 'package:drift/drift.dart';

/// Sync activity log, newest 200 rows kept (FR-22-02). Counts and error
/// class names only, never message text (FR-22-01).
@DataClassName('ActivityRow')
class ActivityEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Epoch ms of the run start.
  IntColumn get at => integer()();

  /// `SMS_SCAN`, `SMS_LIVE`, `GMAIL`, `IMAP`, `STATEMENTS`, `NOTIFICATIONS`.
  TextColumn get source => text()();
  IntColumn get read => integer().withDefault(const Constant(0))();
  IntColumn get relevant => integer().withDefault(const Constant(0))();
  IntColumn get added => integer().withDefault(const Constant(0))();
  IntColumn get merged => integer().withDefault(const Constant(0))();
  IntColumn get review => integer().withDefault(const Constant(0))();
  IntColumn get skipped => integer().withDefault(const Constant(0))();
  IntColumn get emails => integer().withDefault(const Constant(0))();
  IntColumn get statements => integer().withDefault(const Constant(0))();
  IntColumn get locked => integer().withDefault(const Constant(0))();
  IntColumn get millis => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  IntColumn get runs => integer().withDefault(const Constant(1))();
  TextColumn get note => text().nullable()();
}

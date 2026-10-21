import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The single on-device database. Tables are added per feature (see each
/// feature memory file, section 9); every ledger write goes through the
/// transaction repository.
@DriftDatabase()
class AppDatabase extends _$AppDatabase {
  /// Opens the database on [e] (encrypted in the app, in-memory in tests).
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

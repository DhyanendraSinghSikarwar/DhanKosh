import 'package:drift/drift.dart';

/// Accounts the user told the app to ignore (FR-13-22): a message for one is
/// dropped at ingest, so it never creates an account or a transaction.
@DataClassName('IgnoredAccountRow')
class IgnoredAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bankName => text()();
  TextColumn get last4 => text()();
  IntColumn get ignoredAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {bankName, last4},
      ];
}

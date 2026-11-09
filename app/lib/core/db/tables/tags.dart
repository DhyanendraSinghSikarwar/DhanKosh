import 'package:drift/drift.dart';
import 'package:hisaab/core/db/tables/transactions.dart';

/// Free-text labels the user puts on transactions (FR-08-29).
@DataClassName('TagRow')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

/// Which tags a transaction carries.
@DataClassName('TransactionTagRow')
class TransactionTags extends Table {
  IntColumn get transactionId => integer().references(
        Transactions,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get tagId => integer().references(
        Tags,
        #id,
        onDelete: KeyAction.cascade,
      )();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

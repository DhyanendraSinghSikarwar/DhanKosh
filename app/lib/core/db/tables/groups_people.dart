import 'package:drift/drift.dart';
import 'package:hisaab/core/db/tables/transactions.dart';

/// Named bundles of transactions, for example a trip (F-39).
@DataClassName('TxGroupRow')
class TxGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
}

/// Which transactions are in which group.
@DataClassName('TxGroupMemberRow')
class TxGroupMembers extends Table {
  IntColumn get groupId => integer().references(
        TxGroups,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get transactionId => integer().references(
        Transactions,
        #id,
        onDelete: KeyAction.cascade,
      )();

  @override
  Set<Column> get primaryKey => {groupId, transactionId};
}

/// People the user shares costs with (F-40).
@DataClassName('PersonRow')
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get createdAt => integer()();
}

/// Money between the user and a person. Positive: they owe the user.
/// Negative: the user owes them, or they paid something back.
@DataClassName('PersonEntryRow')
class PersonEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer().references(
        People,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();

  /// The shared payment this came from, if any.
  IntColumn get transactionId => integer().nullable().references(
        Transactions,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get createdAt => integer()();
}

/// The parts one transaction is split into by category (F-41). The parts add
/// up to the transaction's amount.
@DataClassName('TxPartRow')
class TxParts extends Table {
  IntColumn get transactionId => integer().references(
        Transactions,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get category => text()();
  IntColumn get amountMinor => integer()();

  @override
  Set<Column> get primaryKey => {transactionId, category};
}

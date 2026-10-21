import 'package:drift/drift.dart';
import 'package:hisaab/core/db/tables/accounts.dart';

/// The ledger (FR-08). Written only by the transaction repository.
@DataClassName('TransactionRow')
@TableIndex(
  name: 'index_transactions_amount_last4_ts',
  columns: {#amountMinor, #accountLast4, #timestamp},
)
@TableIndex(name: 'index_transactions_reference', columns: {#referenceNumber})
@TableIndex(name: 'index_transactions_timestamp', columns: {#timestamp})
@TableIndex(name: 'index_transactions_account', columns: {#accountId})
@TableIndex(name: 'index_transactions_needs_review', columns: {#needsReview})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get type => text()(); // DEBIT|CREDIT|TRANSFER|INVESTMENT
  TextColumn get bankName => text()();
  TextColumn get accountLast4 => text().nullable()();
  TextColumn get accountKind => text()(); // ACCOUNT|CARD
  IntColumn get accountId => integer().nullable().references(
        Accounts,
        #id,
        onDelete: KeyAction.setNull,
      )();
  TextColumn get merchant => text().nullable()();
  TextColumn get upiId => text().nullable()();
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get channel => text()();
  IntColumn get balanceMinor => integer().nullable()();
  IntColumn get availableLimitMinor => integer().nullable()();
  IntColumn get timestamp => integer()(); // epoch ms
  BoolColumn get hasExplicitTime => boolean()();
  TextColumn get category => text()();
  TextColumn get transactionHash => text().unique()();
  RealColumn get confidence => real()();
  BoolColumn get needsReview => boolean().withDefault(const Constant(false))();
  IntColumn get duplicateOfId => integer().nullable()();
  TextColumn get reviewReason => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  TextColumn get subcategory => text().nullable()();
  IntColumn get customCategoryId => integer().nullable()();
  IntColumn get inrMinor => integer().nullable()();
}

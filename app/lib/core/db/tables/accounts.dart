import 'package:drift/drift.dart';

/// Bank accounts and cards (FR-13). Unique on (bank_name, last4).
@DataClassName('AccountRow')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bankName => text()();
  TextColumn get last4 => text()();
  TextColumn get kind => text()(); // ACCOUNT | CARD
  TextColumn get nickname => text().nullable()();
  IntColumn get colorArgb => integer().nullable()();
  IntColumn get latestBalanceMinor => integer().nullable()();
  IntColumn get availableLimitMinor => integer().nullable()();
  IntColumn get balanceUpdatedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get manualBalanceMinor => integer().nullable()();
  IntColumn get manualBalanceAt => integer().nullable()();
  TextColumn get accountType => text().nullable()();
  TextColumn get cardNetwork => text().nullable()();
  IntColumn get linkedAccountId => integer().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  TextColumn get usage => text().withDefault(const Constant('PERSONAL'))();
  IntColumn get maturityDay => integer().nullable()();
  TextColumn get maturityAction => text().nullable()();
  IntColumn get forexMarkupBps => integer().nullable()();
  IntColumn get loanPrincipalMinor => integer().nullable()();
  IntColumn get loanRateBps => integer().nullable()();
  IntColumn get loanTenureMonths => integer().nullable()();
  IntColumn get loanStartDay => integer().nullable()();
  IntColumn get mergedIntoId => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {bankName, last4},
      ];
}

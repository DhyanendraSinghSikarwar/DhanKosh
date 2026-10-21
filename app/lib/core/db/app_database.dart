import 'package:drift/drift.dart';
import 'package:hisaab/core/db/tables/accounts.dart';
import 'package:hisaab/core/db/tables/custom_categories.dart';
import 'package:hisaab/core/db/tables/custom_subcategories.dart';
import 'package:hisaab/core/db/tables/deleted_messages.dart';
import 'package:hisaab/core/db/tables/merchant_rules.dart';
import 'package:hisaab/core/db/tables/processed_emails.dart';
import 'package:hisaab/core/db/tables/settings.dart';
import 'package:hisaab/core/db/tables/transaction_sources.dart';
import 'package:hisaab/core/db/tables/transactions.dart';

part 'app_database.g.dart';

/// The single on-device database. Every ledger write goes through the
/// transaction repository (features/transactions_ledger).
@DriftDatabase(
  tables: [
    Accounts,
    Transactions,
    TransactionSources,
    DeletedMessages,
    MerchantRules,
    CustomCategories,
    CustomSubcategories,
    Settings,
    ProcessedEmails,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database on [e] (encrypted in the app, in-memory in tests).
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2: email ingestion (F-03). Additive, existing rows stay.
          if (from < 2) await m.createTable(processedEmails);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

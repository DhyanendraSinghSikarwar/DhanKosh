import 'package:drift/drift.dart';
import 'package:hisaab/core/db/forex_sql.dart';
import 'package:hisaab/core/db/tables/accounts.dart';
import 'package:hisaab/core/db/tables/activity_entries.dart';
import 'package:hisaab/core/db/tables/alert_state.dart';
import 'package:hisaab/core/db/tables/budgets.dart';
import 'package:hisaab/core/db/tables/card_due_notices.dart';
import 'package:hisaab/core/db/tables/card_overrides.dart';
import 'package:hisaab/core/db/tables/custom_categories.dart';
import 'package:hisaab/core/db/tables/custom_subcategories.dart';
import 'package:hisaab/core/db/tables/deleted_messages.dart';
import 'package:hisaab/core/db/tables/forex_rates.dart';
import 'package:hisaab/core/db/tables/goals.dart';
import 'package:hisaab/core/db/tables/holdings.dart';
import 'package:hisaab/core/db/tables/loan_links.dart';
import 'package:hisaab/core/db/tables/merchant_rules.dart';
import 'package:hisaab/core/db/tables/mf_orders.dart';
import 'package:hisaab/core/db/tables/net_worth_points.dart';
import 'package:hisaab/core/db/tables/processed_emails.dart';
import 'package:hisaab/core/db/tables/recurring_items.dart';
import 'package:hisaab/core/db/tables/settings.dart';
import 'package:hisaab/core/db/tables/sips.dart';
import 'package:hisaab/core/db/tables/statements.dart';
import 'package:hisaab/core/db/tables/transaction_sources.dart';
import 'package:hisaab/core/db/tables/transactions.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

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
    Statements,
    Holdings,
    NetWorthPoints,
    CardDueNotices,
    CardOverrides,
    Budgets,
    RecurringItems,
    ForexRates,
    LoanLinkRows,
    LoanDismissalRows,
    AlertedKeys,
    CardDueReminderState,
    BalanceNoticeDays,
    ActivityEntries,
    Sips,
    MfOrders,
    Goals,
    GoalContributions,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database on [e] (encrypted in the app, in-memory in tests).
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          AppLog.instance.info(
            LogCategory.db,
            'db.create',
            fields: {'version': schemaVersion},
          );
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS activity_entries_at '
            'ON activity_entries (at DESC)',
          );
          await _installTriggers();
        },
        onUpgrade: (m, from, to) async {
          AppLog.instance.info(
            LogCategory.db,
            'db.migrate',
            fields: {'from': from, 'to': to},
          );
          // v1 -> v2: email ingestion (F-03). Additive, existing rows stay.
          if (from < 2) await m.createTable(processedEmails);
          // v2 -> v3: statements, holdings, net worth, card dues (Phase 3).
          if (from < 3) {
            await m.createTable(statements);
            await m.createTable(holdings);
            await m.createTable(netWorthPoints);
            await m.createTable(cardDueNotices);
            await m.createTable(cardOverrides);
          }
          // v3 -> v4: budgets, recurring, forex, loan links, alert state
          // (Phase 4). Additive; the forex triggers are installed below.
          if (from < 4) {
            await m.createTable(budgets);
            await m.createTable(recurringItems);
            await m.createTable(forexRates);
            await m.createTable(loanLinkRows);
            await m.createTable(loanDismissalRows);
            await m.createTable(alertedKeys);
            await m.createTable(cardDueReminderState);
            await m.createTable(balanceNoticeDays);
            await _installTriggers();
            // FR-23-04: backfill so existing rows carry inrMinor.
            await customStatement(ForexSql.recompute);
            await customStatement(
              'UPDATE transactions SET inr_minor = amount_minor '
              "WHERE currency = 'INR' AND inr_minor IS NULL",
            );
          }
          // v4 -> v5: activity log (F-22, Phase 5). Additive.
          if (from < 5) {
            await m.createTable(activityEntries);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS activity_entries_at '
              'ON activity_entries (at DESC)',
            );
          }
          // v5 -> v6: SIPs, MF orders, savings goals (Fold adoption).
          // Additive.
          if (from < 6) {
            await m.createTable(sips);
            await m.createTable(mfOrders);
            await m.createTable(goals);
            await m.createTable(goalContributions);
          }
        },
        beforeOpen: (details) async {
          AppLog.instance.info(
            LogCategory.db,
            'db.open',
            fields: {
              'version': details.versionNow,
              'was': details.versionBefore,
            },
          );
          await customStatement('PRAGMA foreign_keys = ON');
          await _installTriggers();
        },
      );

  Future<void> _installTriggers() async {
    for (final t in ForexSql.triggers) {
      await customStatement(t);
    }
  }
}

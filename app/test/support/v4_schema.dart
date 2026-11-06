import 'package:hisaab/core/db/app_database.dart';

/// Drops everything added in schema v4 and later so a test can fake a v3
/// file.
Future<void> dropV4(AppDatabase db) async {
  await dropV5(db);
  for (final t in [
    'budgets',
    'recurring',
    'forex_rates',
    'loan_link_rows',
    'loan_dismissal_rows',
    'alerted_keys',
    'card_due_reminder_state',
    'balance_notice_days',
  ]) {
    await db.customStatement('DROP TABLE $t');
  }
  await db.customStatement('DROP TRIGGER IF EXISTS transactions_inr_insert');
  await db.customStatement('DROP TRIGGER IF EXISTS transactions_inr_update');
}

/// Drops everything added in schema v5 so a test can fake a v4 file.
Future<void> dropV5(AppDatabase db) async {
  await dropV6(db);
  await db.customStatement('DROP INDEX IF EXISTS activity_entries_at');
  await db.customStatement('DROP TABLE activity_entries');
}

/// Drops everything added in schema v6 so a test can fake a v5 file.
Future<void> dropV6(AppDatabase db) async {
  await dropV7(db);
  for (final t in ['sips', 'mf_orders', 'goals', 'goal_contributions']) {
    await db.customStatement('DROP TABLE $t');
  }
}

/// Drops everything added in schema v7 so a test can fake a v6 file.
Future<void> dropV7(AppDatabase db) async {
  await dropV8(db);
  for (final t in ['unrecognised_messages', 'sender_prefs']) {
    await db.customStatement('DROP TABLE $t');
  }
}

/// Drops everything added in schema v8 so a test can fake a v7 file.
Future<void> dropV8(AppDatabase db) async {
  await dropV9(db);
  await db.customStatement('DROP TABLE ignored_accounts');
}

/// Drops everything added in schema v9 so a test can fake a v8 file.
Future<void> dropV9(AppDatabase db) async {
  await dropV10(db);
  await db.customStatement('ALTER TABLE transactions DROP COLUMN excluded');
}

/// Drops everything added in schema v10 so a test can fake a v9 file.
Future<void> dropV10(AppDatabase db) async {
  await db.customStatement('DROP TABLE merchant_aliases');
}

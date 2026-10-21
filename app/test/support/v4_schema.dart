import 'package:hisaab/core/db/app_database.dart';

/// Drops everything added in schema v4 so a test can fake a v3 file.
Future<void> dropV4(AppDatabase db) async {
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

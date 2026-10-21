import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_state_stores_impl.dart';
import 'package:hisaab/features/alerts_reminders/domain/alerted_key_store.dart';
import 'package:hisaab/features/alerts_reminders/domain/balance_notice_store.dart';
import 'package:hisaab/features/alerts_reminders/domain/card_reminder_state_store.dart';
import 'package:hisaab/features/expense_tracking/data/budget_repository_impl.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_repository.dart';
import 'package:hisaab/features/forex_rates/data/forex_repository_impl.dart';
import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';
import 'package:hisaab/features/forex_rates/domain/forex_repository.dart';
import 'package:hisaab/features/income_tracking/data/income_repository_impl.dart';
import 'package:hisaab/features/income_tracking/domain/income_repository.dart';
import 'package:hisaab/features/loans/data/loan_link_repository_impl.dart';
import 'package:hisaab/features/loans/domain/loan_link_repository.dart';
import 'package:hisaab/features/recurring_transactions/data/recurring_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'phase4_providers.g.dart';

// Phase 4 data-layer wiring (F-10, F-11, F-12, F-15, F-21, F-23).
// Presentation reads the domain interfaces only.

/// Budgets and category spend (F-10).
@Riverpod(keepAlive: true)
BudgetRepository budgetRepository(Ref ref) =>
    BudgetRepositoryImpl(ref.watch(appDatabaseProvider));

/// All budgets, live (F-10).
@riverpod
Stream<List<Budget>> budgets(Ref ref) =>
    ref.watch(budgetRepositoryProvider).watchAll();

/// Income reads (F-11).
@Riverpod(keepAlive: true)
IncomeRepository incomeRepository(Ref ref) =>
    IncomeRepositoryImpl(ref.watch(appDatabaseProvider));

/// User recurring items (F-12).
@Riverpod(keepAlive: true)
RecurringRepository recurringRepository(Ref ref) =>
    RecurringRepositoryImpl(ref.watch(appDatabaseProvider));

/// User recurring items, live (F-12).
@riverpod
Stream<List<RecurringItem>> recurringItems(Ref ref) =>
    ref.watch(recurringRepositoryProvider).watchAll();

/// Loan links and dismissals (F-15).
@Riverpod(keepAlive: true)
LoanLinkRepository loanLinkRepository(Ref ref) =>
    LoanLinkRepositoryImpl(ref.watch(appDatabaseProvider));

/// Alert dedupe keys (F-21).
@Riverpod(keepAlive: true)
AlertedKeyStore alertedKeyStore(Ref ref) =>
    AlertedKeyStoreImpl(ref.watch(appDatabaseProvider));

/// Card reminder state (F-21).
@Riverpod(keepAlive: true)
CardReminderStateStore cardReminderStateStore(Ref ref) =>
    CardReminderStateStoreImpl(ref.watch(appDatabaseProvider));

/// Balance-updated notice days (F-21).
@Riverpod(keepAlive: true)
BalanceNoticeStore balanceNoticeStore(Ref ref) =>
    BalanceNoticeStoreImpl(ref.watch(appDatabaseProvider));

/// Forex rates and the unpriced summary (F-23).
@Riverpod(keepAlive: true)
ForexRepository forexRepository(Ref ref) =>
    ForexRepositoryImpl(ref.watch(appDatabaseProvider));

/// Forex rates, live (F-23).
@riverpod
Stream<List<ForexRate>> forexRates(Ref ref) =>
    ref.watch(forexRepositoryProvider).watchRates();

/// Foreign spend counts, live (F-23).
@riverpod
Stream<List<CurrencyCount>> foreignSpends(Ref ref) =>
    ref.watch(forexRepositoryProvider).watchForeign();

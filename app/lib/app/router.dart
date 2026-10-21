import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/ledger_shell.dart';
import 'package:hisaab/features/accounts_management/presentation/account_detail_screen.dart';
import 'package:hisaab/features/accounts_management/presentation/accounts_management_screen.dart';
import 'package:hisaab/features/alerts_reminders/presentation/alerts_reminders_screen.dart';
import 'package:hisaab/features/alerts_reminders/presentation/alerts_tile.dart';
import 'package:hisaab/features/analytics/presentation/analytics_screen.dart';
import 'package:hisaab/features/backup_export/presentation/backup_export_screen.dart';
import 'package:hisaab/features/backup_export/presentation/backup_tile.dart';
import 'package:hisaab/features/credit_cards/presentation/cards_home_strip.dart';
import 'package:hisaab/features/credit_cards/presentation/credit_cards_screen.dart';
import 'package:hisaab/features/dashboard_home/presentation/dashboard_home_screen.dart';
import 'package:hisaab/features/dedup_review/presentation/dedup_review_screen.dart';
import 'package:hisaab/features/email_ingestion/presentation/email_settings_screen.dart';
import 'package:hisaab/features/expense_tracking/presentation/expense_tracking_screen.dart';
import 'package:hisaab/features/forex_rates/presentation/forex_rates_screen.dart';
import 'package:hisaab/features/forex_rates/presentation/forex_tile.dart';
import 'package:hisaab/features/income_tracking/presentation/income_tracking_screen.dart';
import 'package:hisaab/features/loans/presentation/loan_detail_screen.dart';
import 'package:hisaab/features/loans/presentation/loans_screen.dart';
import 'package:hisaab/features/loans/presentation/loans_tile.dart';
import 'package:hisaab/features/news_support_updates/presentation/news_screen.dart';
import 'package:hisaab/features/news_support_updates/presentation/news_tile.dart';
import 'package:hisaab/features/news_support_updates/presentation/support_screen.dart';
import 'package:hisaab/features/news_support_updates/presentation/support_tile.dart';
import 'package:hisaab/features/news_support_updates/presentation/updates_screen.dart';
import 'package:hisaab/features/news_support_updates/presentation/updates_tile.dart';
import 'package:hisaab/features/notification_ingestion/presentation/notification_access_card.dart';
import 'package:hisaab/features/onboarding_permissions/presentation/welcome_screen.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_screen.dart';
import 'package:hisaab/features/profile/presentation/profile_screen.dart';
import 'package:hisaab/features/recurring_transactions/presentation/bills_tile.dart';
import 'package:hisaab/features/recurring_transactions/presentation/recurring_transactions_screen.dart';
import 'package:hisaab/features/localization/presentation/language_screen.dart';
import 'package:hisaab/features/localization/presentation/language_tile.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_data_sources_screen.dart';
import 'package:hisaab/features/theming_customisation/presentation/customise_tile.dart';
import 'package:hisaab/features/theming_customisation/presentation/theming_customisation_screen.dart';
import 'package:hisaab/features/statement_import/presentation/statements_screen.dart';
import 'package:hisaab/features/statement_import/presentation/statements_tile.dart';
import 'package:hisaab/features/tax_centre/presentation/tax_centre_screen.dart';
import 'package:hisaab/features/tax_centre/presentation/tax_tile.dart';
import 'package:hisaab/features/activity_log/presentation/activity_log_screen.dart';
import 'package:hisaab/features/activity_log/presentation/activity_tile.dart';
import 'package:hisaab/features/security_privacy/presentation/security_privacy_screen.dart';
import 'package:hisaab/features/security_privacy/presentation/security_tile.dart';
import 'package:hisaab/features/transactions_ledger/presentation/add_transaction_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // F-01 gate: Welcome until onboarding is done; blank while unknown.
  final gateChanged = ValueNotifier<int>(0);
  ref
    ..listen(onboardingGateProvider, (_, __) => gateChanged.value++)
    ..onDispose(gateChanged.dispose);
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: gateChanged,
    redirect: (context, state) {
      final gate = ref.read(onboardingGateProvider);
      final at = state.matchedLocation;
      if (!gate.hasValue) return at == '/loading' ? null : '/loading';
      if (gate.requireValue) return at == '/welcome' ? null : '/welcome';
      return at == '/welcome' || at == '/loading' ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(
        path: '/loading',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/transaction/:id',
        builder: (_, state) => TransactionDetailRoute(
          id: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/transactions/add',
        builder: (_, __) => const AddTransactionScreen(),
      ),
      GoRoute(
        path: '/budgets',
        builder: (_, __) => const ExpenseTrackingScreen(),
      ),
      GoRoute(
        path: '/income',
        builder: (_, __) => const IncomeTrackingScreen(),
      ),
      GoRoute(path: '/tax', builder: (_, __) => const TaxCentreScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/cards', builder: (_, __) => const CreditCardsScreen()),
      GoRoute(
        path: '/statements',
        builder: (_, __) => const StatementsScreen(),
      ),
      GoRoute(path: '/review', builder: (_, __) => const DedupReviewScreen()),
      GoRoute(
        path: '/bills',
        builder: (_, __) => const RecurringTransactionsScreen(),
      ),
      GoRoute(
        path: '/loans',
        builder: (_, __) => const LoansScreen(),
        routes: [
          GoRoute(
            path: ':key',
            builder: (_, state) =>
                LoanDetailScreen(loanKey: state.pathParameters['key']!),
          ),
        ],
      ),
      GoRoute(
        path: '/settings/alerts',
        builder: (_, __) => const AlertsRemindersScreen(),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (_, __) => const BackupExportScreen(),
      ),
      GoRoute(path: '/news', builder: (_, __) => const NewsScreen()),
      GoRoute(
        path: '/settings/support',
        builder: (_, __) => const SupportScreen(),
      ),
      GoRoute(
        path: '/settings/updates',
        builder: (_, __) => const UpdatesScreen(),
      ),
      GoRoute(
        path: '/settings/forex',
        builder: (_, __) => const ForexRatesScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (_, __) => const ThemingCustomisationScreen(),
      ),
      GoRoute(
        path: '/settings/language',
        builder: (_, __) => const LanguageScreen(),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (_, __) => const SecurityPrivacyScreen(),
      ),
      GoRoute(path: '/activity', builder: (_, __) => const ActivityLogScreen()),
      GoRoute(
        path: '/settings/email',
        builder: (_, __) => const EmailSettingsScreen(),
      ),
      GoRoute(
        path: '/accounts',
        builder: (_, __) => const AccountsManagementScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => AccountDetailScreen(
              accountId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ScaffoldWithNavBar(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const DashboardHomeScreen(
                  cardsSection: CardsHomeStrip(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (_, __) => const TransactionsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/portfolio',
                builder: (_, __) => const PortfolioScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analysis',
                builder: (_, __) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, __) => const SettingsDataSourcesScreen(
                  notificationCard: NotificationAccessCard(),
                  statementsTile: StatementsTile(),
                  billsTile: BillsTile(),
                  loansTile: LoansTile(),
                  alertsTile: AlertsTile(),
                  forexTile: ForexTile(),
                  backupTile: BackupTile(),
                  taxTile: TaxTile(),
                  securityTile: SecurityTile(),
                  activityTile: ActivityTile(),
                  newsTile: NewsTile(),
                  supportTile: SupportTile(),
                  updatesTile: UpdatesTile(),
                  customiseTile: CustomiseTile(),
                  languageTile: LanguageTile(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Analysis',
          ),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_card_marks_provider.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/ledger_shell.dart';
import 'package:hisaab/features/accounts_management/presentation/account_detail_screen.dart';
import 'package:hisaab/features/accounts_management/presentation/accounts_management_screen.dart';
import 'package:hisaab/features/activity_log/presentation/activity_log_screen.dart';
import 'package:hisaab/features/activity_log/presentation/activity_tile.dart';
import 'package:hisaab/features/alerts_reminders/presentation/alert_action_screen.dart';
import 'package:hisaab/features/alerts_reminders/presentation/alerts_reminders_screen.dart';
import 'package:hisaab/features/alerts_reminders/presentation/alerts_tile.dart';
import 'package:hisaab/features/analytics/presentation/analytics_screen.dart';
import 'package:hisaab/features/backup_export/presentation/backup_export_screen.dart';
import 'package:hisaab/features/backup_export/presentation/backup_tile.dart';
import 'package:hisaab/features/categorization/presentation/category_detail_screen.dart';
import 'package:hisaab/features/categorization/presentation/rules_screen.dart';
import 'package:hisaab/features/categorization/presentation/rules_tile.dart';
import 'package:hisaab/features/credit_cards/presentation/bills_card_dues.dart';
import 'package:hisaab/features/credit_cards/presentation/card_detail_screen.dart';
import 'package:hisaab/features/credit_cards/presentation/cards_home_strip.dart';
import 'package:hisaab/features/credit_cards/presentation/credit_cards_screen.dart';
import 'package:hisaab/features/dashboard_home/presentation/dashboard_home_screen.dart';
import 'package:hisaab/features/dedup_review/presentation/dedup_review_screen.dart';
import 'package:hisaab/features/diagnostic_log/presentation/diagnostic_log_screen.dart';
import 'package:hisaab/features/diagnostic_log/presentation/diagnostic_log_tile.dart';
import 'package:hisaab/features/email_ingestion/presentation/email_settings_screen.dart';
import 'package:hisaab/features/expense_tracking/presentation/expense_tracking_screen.dart';
import 'package:hisaab/features/forex_rates/presentation/forex_rates_screen.dart';
import 'package:hisaab/features/forex_rates/presentation/forex_tile.dart';
import 'package:hisaab/features/income_tracking/presentation/income_tracking_screen.dart';
import 'package:hisaab/features/loans/presentation/loan_detail_screen.dart';
import 'package:hisaab/features/loans/presentation/loan_link_prompt_screen.dart';
import 'package:hisaab/features/loans/presentation/loans_screen.dart';
import 'package:hisaab/features/loans/presentation/loans_tile.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/localization/presentation/language_screen.dart';
import 'package:hisaab/features/localization/presentation/language_tile.dart';
import 'package:hisaab/features/news_support_updates/presentation/news_screen.dart';
import 'package:hisaab/features/news_support_updates/presentation/news_tile.dart';
import 'package:hisaab/features/news_support_updates/presentation/support_screen.dart';
import 'package:hisaab/features/news_support_updates/presentation/support_tile.dart';
import 'package:hisaab/features/news_support_updates/presentation/updates_screen.dart';
import 'package:hisaab/features/news_support_updates/presentation/updates_tile.dart';
import 'package:hisaab/features/notification_ingestion/presentation/notification_access_card.dart';
import 'package:hisaab/features/notification_ingestion/presentation/watched_apps_screen.dart';
import 'package:hisaab/features/onboarding_permissions/presentation/welcome_screen.dart';
import 'package:hisaab/features/people_split/presentation/people_screen.dart';
import 'package:hisaab/features/people_split/presentation/people_tile.dart';
import 'package:hisaab/features/people_split/presentation/person_detail_screen.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_screen.dart';
import 'package:hisaab/features/profile/presentation/bank_details_sheet.dart';
import 'package:hisaab/features/profile/presentation/profile_screen.dart';
import 'package:hisaab/features/recurring_transactions/presentation/bills_tile.dart';
import 'package:hisaab/features/recurring_transactions/presentation/recurring_transactions_screen.dart';
import 'package:hisaab/features/recurring_transactions/presentation/sip_section.dart';
import 'package:hisaab/features/recurring_transactions/presentation/sip_setup_sheet.dart';
import 'package:hisaab/features/savings_goals/presentation/goals_screen.dart';
import 'package:hisaab/features/savings_goals/presentation/goals_tile.dart';
import 'package:hisaab/features/security_privacy/presentation/security_privacy_screen.dart';
import 'package:hisaab/features/security_privacy/presentation/security_tile.dart';
import 'package:hisaab/features/settings_data_sources/presentation/sender_lists_screen.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_data_sources_screen.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/statement_preview.dart';
import 'package:hisaab/features/statement_import/presentation/column_mapping_screen.dart';
import 'package:hisaab/features/statement_import/presentation/statement_detail_screen.dart';
import 'package:hisaab/features/statement_import/presentation/statement_preview_screen.dart';
import 'package:hisaab/features/statement_import/presentation/statements_screen.dart';
import 'package:hisaab/features/statement_import/presentation/statements_tile.dart';
import 'package:hisaab/features/tax_centre/presentation/tax_centre_screen.dart';
import 'package:hisaab/features/tax_centre/presentation/tax_tile.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
import 'package:hisaab/features/theming_customisation/presentation/customise_tile.dart';
import 'package:hisaab/features/theming_customisation/presentation/section_layout_editor.dart';
import 'package:hisaab/features/theming_customisation/presentation/theming_customisation_screen.dart';
import 'package:hisaab/features/transaction_groups/presentation/group_detail_screen.dart';
import 'package:hisaab/features/transaction_groups/presentation/groups_screen.dart';
import 'package:hisaab/features/transaction_groups/presentation/groups_tile.dart';
import 'package:hisaab/features/transactions_ledger/domain/add_draft.dart';
import 'package:hisaab/features/transactions_ledger/presentation/add_transaction_screen.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_tx_tile.dart';
import 'package:hisaab/features/unrecognised_messages/presentation/learned_senders_screen.dart';
import 'package:hisaab/features/unrecognised_messages/presentation/unrecognised_screen.dart';
import 'package:hisaab/features/unrecognised_messages/presentation/unrecognised_tile.dart';
import 'package:hisaab/shared/widgets/pill_navigation_bar.dart';

Widget _sipSheet(BuildContext _) => const SipSetupSheet();

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
        builder: (_, state) => AddTransactionScreen(
          draft: state.extra as AddDraft? ??
              addDraftFromLink(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/category/:id',
        builder: (_, state) =>
            CategoryDetailScreen(id: state.pathParameters['id']!),
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
      GoRoute(path: '/rules', builder: (_, __) => const RulesScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/goals', builder: (_, __) => const GoalsScreen()),
      GoRoute(
        path: '/cards',
        builder: (_, __) => const CreditCardsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => CardDetailScreen(
              cardId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/statements',
        builder: (_, state) => StatementsScreen(
          unlockId: int.tryParse(state.uri.queryParameters['unlock'] ?? ''),
        ),
        routes: [
          // Before ':id', or "map" would be read as a statement id.
          GoRoute(
            path: 'preview',
            builder: (_, state) => StatementPreviewScreen(
              preview: state.extra! as StatementPreview,
            ),
          ),
          GoRoute(
            path: 'map',
            builder: (_, state) =>
                ColumnMappingScreen(file: state.extra! as PickedFile),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => StatementDetailScreen(
              id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
      GoRoute(path: '/review', builder: (_, __) => const DedupReviewScreen()),
      GoRoute(
        path: '/review/unrecognised',
        builder: (_, __) => const UnrecognisedScreen(),
        routes: [
          GoRoute(
            path: 'senders',
            builder: (_, __) => const LearnedSendersScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/bills',
        builder: (_, __) => RecurringTransactionsScreen(
          extraSection: (month, day) => BillsCardDues(month: month, day: day),
          cardDays: cardDueDatesProvider,
        ),
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
        path: '/loan-link/:txId',
        builder: (_, state) => LoanLinkPromptScreen(
          txId: int.tryParse(state.pathParameters['txId'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/alert-action',
        builder: (_, state) =>
            AlertActionScreen(query: state.uri.queryParameters),
      ),
      GoRoute(
        path: '/groups',
        builder: (_, __) => const GroupsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => GroupDetailScreen(
              id: int.parse(state.pathParameters['id']!),
              rowBuilder: (tx, {required masked}) =>
                  LedgerTxTile(tx: tx, masked: masked),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/people',
        builder: (_, __) => const PeopleScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => PersonDetailScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
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
      GoRoute(
        path: '/settings/logs',
        builder: (_, __) => const DiagnosticLogScreen(),
      ),
      GoRoute(
        path: '/settings/watched-apps',
        builder: (_, __) => const WatchedAppsScreen(),
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
        path: '/settings/senders',
        builder: (_, __) => const SenderListsScreen(),
      ),
      GoRoute(
        path: '/accounts',
        builder: (_, __) => const AccountsManagementScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => AccountDetailScreen(
              accountId: int.parse(state.pathParameters['id']!),
              unlockSheet: (acc) => BankDetailsSheet(account: acc),
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
                  layoutEditor: SectionLayoutEditor(screenId: ScreenIds.home),
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
                builder: (_, __) => const PortfolioScreen(
                  sipSection: SipSection(),
                  sipSheet: _sipSheet,
                  layoutEditor:
                      SectionLayoutEditor(screenId: ScreenIds.portfolio),
                ),
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
                  goalsTile: GoalsTile(),
                  loansTile: LoansTile(),
                  alertsTile: AlertsTile(),
                  forexTile: ForexTile(),
                  backupTile: BackupTile(),
                  taxTile: TaxTile(),
                  rulesTile: RulesTile(),
                  groupsTile: GroupsTile(),
                  peopleTile: PeopleTile(),
                  securityTile: SecurityTile(),
                  activityTile: ActivityTile(),
                  unrecognisedTile: UnrecognisedTile(),
                  newsTile: NewsTile(),
                  supportTile: SupportTile(),
                  updatesTile: UpdatesTile(),
                  diagnosticLogTile: DiagnosticLogTile(),
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
    // Back from another tab goes to Home first; only Home lets the app leave
    // (FR-17-49).
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: PillNavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: t('Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: t('Transactions'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline),
              selectedIcon: const Icon(Icons.pie_chart),
              label: t('Portfolio'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: t('Analysis'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu),
              selectedIcon: const Icon(Icons.menu_open),
              label: t('More'),
            ),
          ],
        ),
      ),
    );
  }
}

const _tabRoots = {
  '/home',
  '/transactions',
  '/portfolio',
  '/analysis',
  '/more',
};

/// Opens [location] with Home underneath, so Back always has somewhere to go
/// (FR-17-49). A tab root or an unknown place just opens.
void openWithBack(GoRouter router, String location) {
  final path = Uri.parse(location).path;
  if (_tabRoots.contains(path) || path == '/welcome' || path == '/loading') {
    router.go(location);
    return;
  }
  router.go('/home');
  unawaited(router.push<void>(location));
}

/// After a cold start or a restore that lands on one inner page with nothing
/// below it, puts Home underneath (FR-17-49). Returns whether it did.
bool ensureBackStack(GoRouter router) {
  final uri = router.routerDelegate.currentConfiguration.uri;
  if (router.canPop() || _tabRoots.contains(uri.path)) return false;
  if (uri.path == '/welcome' || uri.path == '/loading' || uri.path == '/') {
    return false;
  }
  openWithBack(router, uri.toString());
  return true;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/ledger_shell.dart';
import 'package:hisaab/features/accounts_management/presentation/account_detail_screen.dart';
import 'package:hisaab/features/accounts_management/presentation/accounts_management_screen.dart';
import 'package:hisaab/features/analytics/presentation/analytics_screen.dart';
import 'package:hisaab/features/dashboard_home/presentation/dashboard_home_screen.dart';
import 'package:hisaab/features/dedup_review/presentation/dedup_review_screen.dart';
import 'package:hisaab/features/onboarding_permissions/presentation/welcome_screen.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_screen.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_data_sources_screen.dart';
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
      GoRoute(path: '/review', builder: (_, __) => const DedupReviewScreen()),
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
                builder: (_, __) => const DashboardHomeScreen(),
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
                builder: (_, __) => const SettingsDataSourcesScreen(),
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

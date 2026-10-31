import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/layout_providers.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_accounts_strip.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_attention_card.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_budget_widgets.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_categories_card.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_header.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_insights_card.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_providers.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_recent_list.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_sms_card.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_spent_card.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_upcoming_card.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Home: greeting, month spent/income, review notice, recent, accounts
/// (F-17, Phase 1 subset of FR-17-01..03, 06, 12, 14, 19).
class DashboardHomeScreen extends ConsumerStatefulWidget {
  const DashboardHomeScreen({
    this.cardsSection,
    this.goalsSection,
    this.layoutEditor,
    super.key,
  });

  /// Optional cards strip embedded by the app composition (F-14).
  final Widget? cardsSection;

  /// Optional goals summary embedded by the app composition (FR-17-30). It
  /// renders nothing when there are no goals.
  final Widget? goalsSection;

  /// Section editor shown in edit mode, composed by the router from
  /// Customise (FR-28-15). Without it the edit button opens Customise.
  final Widget? layoutEditor;

  @override
  ConsumerState<DashboardHomeScreen> createState() =>
      _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends ConsumerState<DashboardHomeScreen> {
  bool _editing = false;

  void _toggleEdit() {
    if (widget.layoutEditor == null) {
      unawaited(context.push('/settings/appearance'));
    } else {
      setState(() => _editing = !_editing);
    }
  }

  Widget? _section(
    String id,
    List<LedgerTx> recent,
    bool masked,
  ) =>
      switch (id) {
        'spent' => const HomeSpentCard(),
        'cards' => widget.cardsSection,
        'cashflow' => const HomeCashFlowCard(),
        'upcoming' => const HomeUpcomingCard(),
        'insights' => const HomeInsightsCard(),
        'categories' => const HomeCategoriesCard(),
        'recent' => HomeRecentList(txs: recent, masked: masked),
        'budgets' => const HomeBudgetsCard(),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final totals = ref.watch(homeTotalsProvider).value;
    final recent = ref.watch(homeRecentProvider).value;
    final accounts = ref.watch(homeAccountsProvider).value;
    final visible = ref.watch(visibleSectionsProvider(ScreenIds.home));
    final rest = [
      for (final i in visible)
        if (i != 'categories') i,
    ];
    final loaded = totals != null && recent != null && accounts != null;
    final empty =
        loaded && recent.isEmpty && accounts.isEmpty && (totals.count == 0);
    return Scaffold(
      body: SafeArea(
        child: !loaded
            ? const Center(child: Text('Loading…'))
            : empty
                ? _EmptyHome(masked: masked)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      HomeHeader(
                        masked: masked,
                        editing: _editing,
                        onEdit: _toggleEdit,
                      ),
                      const _PrivacyBadge(),
                      const SizedBox(height: 16),
                      if (_editing && widget.layoutEditor != null)
                        AppCard(
                          key: const Key('home_edit_card'),
                          child: widget.layoutEditor!,
                        )
                      else ...[
                        const HomeSmsCard(),
                        const HomeAttentionCard(),
                        for (final id in rest) ...[
                          if (_section(id, recent, masked) case final w?) ...[
                            w,
                            const SizedBox(height: 16),
                          ],
                          if (widget.goalsSection != null &&
                              _goalsAfter(rest) == id) ...[
                            widget.goalsSection!,
                            const SizedBox(height: 16),
                          ],
                        ],
                        HomeAccountsStrip(accounts: accounts, masked: masked),
                        if (visible.contains('categories')) ...[
                          const SizedBox(height: 16),
                          const HomeCategoriesCard(),
                        ],
                      ],
                    ],
                  ),
      ),
    );
  }

  /// Goals sit after the last visible of cards or budgets, else after the
  /// last visible section (FR-17-30).
  String _goalsAfter(List<String> visible) {
    final ix = visible.where((i) => i == 'cards' || i == 'budgets').toList();
    if (ix.isNotEmpty) return ix.last;
    return visible.isEmpty ? '' : visible.last;
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      key: const Key('home_privacy_badge'),
      children: [
        Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          'Data stays on this phone',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.masked});

  final bool masked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              HomeHeader(masked: masked),
              const _PrivacyBadge(),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: HomeSmsCard(),
              ),
              const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No transactions yet',
                hint: 'Read your bank SMS to get started.',
              ),
              FilledButton(
                key: const Key('home_scan_sms'),
                onPressed: () => context.go('/more'),
                child: const Text('Scan SMS'),
              ),
              TextButton(
                key: const Key('home_import_statement'),
                onPressed: () => context.push('/statements'),
                child: const Text('Import your first statement'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

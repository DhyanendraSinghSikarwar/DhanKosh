import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_accounts_strip.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_attention_card.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_budget_widgets.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_net_worth_card.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_providers.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_recent_list.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_sms_card.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Home: greeting, month spent/income, review notice, recent, accounts
/// (F-17, Phase 1 subset of FR-17-01..03, 06, 12, 14, 19).
class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({this.cardsSection, this.goalsSection, super.key});

  /// Optional cards strip embedded by the app composition (F-14).
  final Widget? cardsSection;

  /// Optional goals summary embedded by the app composition (FR-17-30). It
  /// renders nothing when there are no goals.
  final Widget? goalsSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final totals = ref.watch(homeTotalsProvider).value;
    final recent = ref.watch(homeRecentProvider).value;
    final accounts = ref.watch(homeAccountsProvider).value;
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
                      _Header(masked: masked),
                      const _PrivacyBadge(),
                      const SizedBox(height: 16),
                      HomeNetWorthCard(masked: masked),
                      const HomeSmsCard(),
                      const HomeAttentionCard(),
                      const _SpentCard(),
                      const SizedBox(height: 16),
                      const HomeCashFlowCard(),
                      const HomeBudgetsCard(),
                      if (cardsSection != null) ...[
                        cardsSection!,
                        const SizedBox(height: 16),
                      ],
                      if (goalsSection != null) ...[
                        goalsSection!,
                        const SizedBox(height: 16),
                      ],
                      HomeRecentList(txs: recent, masked: masked),
                      const SizedBox(height: 16),
                      HomeAccountsStrip(accounts: accounts, masked: masked),
                    ],
                  ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.masked});

  final bool masked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting(DateTime.now().hour),
                key: const Key('home_greeting'),
                style: theme.textTheme.bodyMedium,
              ),
              Text('Welcome', style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        IconButton(
          key: const Key('home_eye'),
          tooltip: masked ? 'Show amounts' : 'Hide amounts',
          icon: Icon(
            masked ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          onPressed: () => ref
              .read(settingsRepositoryProvider)
              .write(SettingKeys.hideAmounts, !masked),
        ),
        const _InboxBell(),
        IconButton(
          key: const Key('home_accounts_button'),
          tooltip: 'Accounts',
          icon: const Icon(Icons.account_balance_outlined),
          onPressed: () => context.push('/accounts'),
        ),
      ],
    );
  }
}

class _InboxBell extends ConsumerWidget {
  const _InboxBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(inboxUnreadProvider);
    return IconButton(
      key: const Key('home_bell'),
      tooltip: 'Inbox',
      icon: Badge(
        key: const Key('home_bell_badge'),
        isLabelVisible: n > 0,
        label: Text(n > 99 ? '99+' : '$n'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => context.push('/activity'),
    );
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

class _SpentCard extends ConsumerWidget {
  const _SpentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<SemanticColors>();
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final month = ref.watch(homeMonthProvider);
    final totals = ref.watch(homeTotalsProvider).value;
    final isCurrent = month.isCurrent(DateTime.now());
    final notifier = ref.read(homeMonthProvider.notifier);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('home_month_prev'),
                icon: const Icon(Icons.chevron_left),
                onPressed: notifier.previous,
              ),
              Expanded(
                child: Text(
                  month.label,
                  key: const Key('home_month_label'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('home_month_next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrent ? null : notifier.next,
              ),
            ],
          ),
          Text(isCurrent ? 'Spent this month' : 'Spent'),
          InkWell(
            key: const Key('home_spent_tap'),
            onTap: () => context.go('/analysis'),
            child: Text(
              formatAmount(
                totals?.netSpentMinor ?? 0,
                masked: masked,
              ),
              key: const Key('home_spent'),
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Income',
                  value: formatAmount(
                    totals?.incomeMinor ?? 0,
                    masked: masked,
                  ),
                  color: colors?.income,
                  valueKey: const Key('home_income'),
                ),
              ),
              Expanded(
                child: _Tile(
                  label: 'Saved',
                  value: formatAmount(
                    (totals?.incomeMinor ?? 0) - (totals?.outMinor ?? 0),
                    masked: masked,
                  ),
                  valueKey: const Key('home_saved'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.valueKey,
    this.color,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          value,
          key: valueKey,
          style: theme.textTheme.titleMedium?.copyWith(color: color),
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
              _Header(masked: masked),
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

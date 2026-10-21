import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_accounts_strip.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_providers.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_recent_list.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Home: greeting, month spent/income, review notice, recent, accounts
/// (F-17, Phase 1 subset of FR-17-01..03, 06, 12, 14, 19).
class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

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
                      const SizedBox(height: 16),
                      const _ReviewNotice(),
                      const _SpentCard(),
                      const SizedBox(height: 16),
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

class _ReviewNotice extends ConsumerWidget {
  const _ReviewNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(homeReviewCountProvider).value ?? 0;
    if (n == 0) return const SizedBox.shrink();
    final warn = Theme.of(context).extension<SemanticColors>()?.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        key: const Key('home_review_notice'),
        onTap: () => context.push('/review'),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: warn),
            const SizedBox(width: 12),
            Expanded(child: Text('$n to review')),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
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
          Text(
            formatAmount(
              totals?.netSpentMinor ?? 0,
              masked: masked,
            ),
            key: const Key('home_spent'),
            style: theme.textTheme.headlineMedium,
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
      ],
    );
  }
}

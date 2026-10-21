import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Total balance plus a chip per account; opens Accounts.
class HomeAccountsStrip extends StatelessWidget {
  const HomeAccountsStrip({
    required this.accounts,
    required this.masked,
    super.key,
  });

  final List<AccountWithActivity> accounts;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = liquidBalanceMinor(accounts);
    return AppCard(
      key: const Key('home_accounts_strip'),
      onTap: () => context.push('/accounts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Accounts', style: theme.textTheme.titleMedium),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          if (total != null)
            Text(
              formatAmount(total, masked: masked),
              key: const Key('home_balance'),
              style: theme.textTheme.titleLarge,
            ),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            const Text('No accounts yet')
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final a in accounts)
                  Chip(
                    label: Text(a.account.label),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// Total balance plus a chip per account; opens Accounts.
class HomeAccountsStrip extends StatefulWidget {
  const HomeAccountsStrip({
    required this.accounts,
    required this.masked,
    super.key,
  });

  final List<AccountWithActivity> accounts;
  final bool masked;

  @override
  State<HomeAccountsStrip> createState() => _HomeAccountsStripState();
}

class _HomeAccountsStripState extends State<HomeAccountsStrip> {
  bool _open = true;

  List<AccountWithActivity> get accounts => widget.accounts;
  bool get masked => widget.masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = liquidBalanceMinor(accounts);
    return AppCard(
      key: const Key('home_accounts_strip'),
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/accounts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            'Accounts',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkResponse(
                  key: const Key('home_accounts_fold'),
                  radius: 16,
                  onTap: () => setState(() => _open = !_open),
                  child: Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '›',
                  style: MockText.body(
                    context,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (total != null)
            Text(
              formatAmount(total, masked: masked, paise: false),
              key: const Key('home_balance'),
              style: MockText.mid(context),
            ),
          if (_open) ...[
            const SizedBox(height: 8),
            if (accounts.isEmpty)
              Text('No accounts yet', style: MockText.small(context))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in accounts)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        a.account.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

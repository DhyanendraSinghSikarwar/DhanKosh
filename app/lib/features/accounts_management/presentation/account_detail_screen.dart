import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/accounts_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/presentation/account_actions.dart';
import 'package:hisaab/features/accounts_management/presentation/account_edit_sheet.dart';
import 'package:hisaab/features/accounts_management/presentation/account_providers.dart';
import 'package:hisaab/features/accounts_management/presentation/account_series_chart.dart';
import 'package:hisaab/features/accounts_management/presentation/account_tile.dart';
import 'package:hisaab/features/accounts_management/presentation/gap_card.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:parser_core/parser_core.dart';

enum _Action { edit, rename, type, balance, merge, hide, delete }

/// Account detail (route `/accounts/:id`): balance, estimated flag, this
/// month's spend, recent activity, actions (FR-13-06, 10, 11, 17 basics).
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({
    required this.accountId,
    this.unlockSheet,
    super.key,
  });

  final int accountId;

  /// Statement unlock form from the profile feature, bound by the router.
  final Widget Function(Account)? unlockSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final theme = Theme.of(context);
    final items = ref.watch(accountsWithActivityProvider).value;
    final item = items?.where((a) => a.account.id == accountId).firstOrNull;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(items == null ? 'Loading…' : 'Not found')),
      );
    }
    final a = item.account;
    final bal = item.currentBalanceMinor;
    final repo = ref.read(accountRepositoryProvider);
    final txs = ref.watch(accountActivityProvider(accountId)).value ?? const [];
    final gaps = ref.watch(openGapsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(a.label),
        actions: [
          PopupMenuButton<_Action>(
            key: const Key('account_menu'),
            onSelected: (v) async {
              switch (v) {
                case _Action.edit:
                  await showAccountEditSheet(
                    context,
                    a,
                    unlockSheet: unlockSheet,
                  );
                case _Action.merge:
                  final done = await mergeAccountInto(
                    context,
                    ref.read(accountAdminRepositoryProvider),
                    a,
                  );
                  if (done && context.mounted) context.pop();
                case _Action.rename:
                  await renameAccount(context, repo, a);
                case _Action.type:
                  await changeAccountType(context, repo, a);
                case _Action.balance:
                  await setBalance(
                    context,
                    repo,
                    a,
                    nowMs: DateTime.now().millisecondsSinceEpoch,
                  );
                case _Action.hide:
                  await repo.setHidden(a.id, hidden: true);
                  if (context.mounted) context.pop();
                case _Action.delete:
                  final gone = await deleteAccountWithOptions(
                    context,
                    account: a,
                    accounts: repo,
                    transactions: ref.read(transactionRepositoryProvider),
                    identities: ref.read(bankIdentityRepositoryProvider),
                  );
                  if (gone && context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Action.edit, child: Text('Edit')),
              PopupMenuItem(value: _Action.rename, child: Text('Rename')),
              PopupMenuItem(value: _Action.type, child: Text('Set type')),
              PopupMenuItem(value: _Action.balance, child: Text('Set balance')),
              PopupMenuItem(value: _Action.merge, child: Text('Merge into…')),
              PopupMenuItem(value: _Action.hide, child: Text('Hide')),
              PopupMenuItem(value: _Action.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final g in gaps.where((g) => g.accountId == accountId))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GapCard(gap: g, account: a),
            ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.kind == AccountKind.card ? 'Limit left' : 'Balance',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  bal == null ? 'Not known' : formatAmount(bal, masked: masked),
                  key: const Key('detail_balance'),
                  style: theme.textTheme.headlineMedium,
                ),
                if (item.balanceIsEstimated)
                  Text(
                    'Estimated, from later transactions',
                    key: const Key('detail_estimated'),
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Text(
                  'Spent this month: '
                  '${formatAmount(item.monthSpent, masked: masked)}',
                  key: const Key('detail_month_spent'),
                ),
                if (a.accountType != null)
                  Text(accountTypeLabel(a.accountType!)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AccountSeriesChart(accountId: accountId),
          const SizedBox(height: 16),
          Text('Recent activity', style: theme.textTheme.titleMedium),
          if (txs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No transactions yet'),
            ),
          for (final t in txs)
            ListTile(
              key: Key('activity_${t.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(t.title),
              subtitle: Text(t.category.label),
              trailing: Text(
                '${t.type == TransactionType.credit ? '+' : '-'}'
                '${formatAmount(t.inrMinor ?? t.amountMinor, masked: masked)}',
              ),
              onTap: () => context.push('/transaction/${t.id}'),
            ),
        ],
      ),
    );
  }
}

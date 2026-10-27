import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/accounts_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/restore_missing.dart';
import 'package:hisaab/features/accounts_management/presentation/account_providers.dart';
import 'package:hisaab/features/accounts_management/presentation/account_suggestions.dart';
import 'package:hisaab/features/accounts_management/presentation/account_tile.dart';
import 'package:hisaab/features/accounts_management/presentation/add_account_sheet.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';
import 'package:parser_core/parser_core.dart';

/// Accounts list (route `/accounts`): FR-13-04 (sections, Phase 1), FR-13-05
/// (add), FR-13-10 (hidden section).
class AccountsManagementScreen extends ConsumerWidget {
  const AccountsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final list = ref.watch(accountsWithActivityProvider);
    final hidden = ref.watch(hiddenAccountsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          PopupMenuButton<int>(
            key: const Key('accounts_menu'),
            onSelected: (_) async {
              final n = await restoreMissingAccounts(
                ref.read(accountAdminRepositoryProvider),
                ref.read(transactionRepositoryProvider),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Restored $n accounts')),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('Restore missing accounts')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('accounts_add'),
        onPressed: () => showAddAccountSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: list.when(
        loading: () => const Center(child: Text('Loading…')),
        error: (e, _) => const Center(child: Text("Couldn't load accounts")),
        data: (items) {
          if (items.isEmpty && hidden.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No accounts yet',
              hint: 'Add one, or read your SMS.',
            );
          }
          final banks =
              items.where((a) => a.account.kind == AccountKind.account);
          final cards = items.where((a) => a.account.kind == AccountKind.card);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              AccountSuggestions(items),
              _Section('Accounts', banks, masked: masked),
              _Section('Cards', cards, masked: masked),
              if (hidden.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Hidden (${hidden.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final a in hidden)
                  ListTile(
                    key: Key('hidden_${a.id}'),
                    title: Text(a.label),
                    trailing: TextButton(
                      onPressed: () => ref
                          .read(accountRepositoryProvider)
                          .setHidden(a.id, hidden: false),
                      child: const Text('Show again'),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.items, {required this.masked});

  final String title;
  final Iterable<AccountWithActivity> items;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '$title (${items.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final a in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AccountTile(
              item: a,
              masked: masked,
              onTap: () => context.push('/accounts/${a.account.id}'),
            ),
          ),
      ],
    );
  }
}

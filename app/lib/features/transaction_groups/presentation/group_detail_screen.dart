import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/groups_people_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/transaction_groups/presentation/groups_screen.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// One group (FR-39-03): totals, its transactions, add and remove.
class GroupDetailScreen extends ConsumerWidget {
  /// Creates the screen.
  const GroupDetailScreen({
    required this.id,
    required this.rowBuilder,
    super.key,
  });

  /// How one transaction is drawn; composed in `app/` so features stay apart.
  final Widget Function(LedgerTx tx, {required bool masked}) rowBuilder;

  /// Group id.
  final int id;

  Future<void> _addTransactions(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(transactionRepositoryProvider);
    final all = await repo.watch(const LedgerFilter(), limit: 150).first;
    final members = {
      for (final t in await repo.watch(LedgerFilter(groupId: id)).first) t.id,
    };
    final choices = [
      for (final t in all)
        if (!members.contains(t.id)) t,
    ];
    if (!context.mounted) return;
    final picked = <int>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.75,
            child: Column(
              children: [
                ListTile(
                  title: Text(t('Add transactions')),
                  trailing: FilledButton(
                    key: const Key('group_add_done'),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(t('Add')),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final tx in choices)
                        CheckboxListTile(
                          key: Key('group_pick_${tx.id}'),
                          value: picked.contains(tx.id),
                          title: Text(tx.title),
                          subtitle: Text(
                            '${tx.category.label} · ${tx.amountMinor ~/ 100}',
                          ),
                          onChanged: (v) => set(
                            () => v == true
                                ? picked.add(tx.id)
                                : picked.remove(tx.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true && picked.isNotEmpty) {
      await ref.read(txGroupRepositoryProvider).add(id, picked.toList());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final group =
        ref.watch(txGroupsProvider).value?.where((g) => g.id == id).firstOrNull;
    final rows =
        ref.watch(groupMembersProvider(id)).value ?? const <LedgerTx>[];
    final repo = ref.read(txGroupRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? t('Group')),
        actions: [
          IconButton(
            key: const Key('group_rename'),
            tooltip: t('Rename'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final n = await askGroupName(
                context,
                title: t('Rename'),
                initial: group?.name,
              );
              if (n != null && n.isNotEmpty) await repo.rename(id, n);
            },
          ),
          IconButton(
            key: const Key('group_delete'),
            tooltip: t('Delete'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await repo.delete(id);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('group_add'),
        onPressed: () => _addTransactions(context, ref),
        icon: const Icon(Icons.add),
        label: Text(t('Add transactions')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (group != null)
            AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Figure(
                    key: const Key('group_spent'),
                    label: t('Spent'),
                    value: formatAmount(
                      group.spentMinor,
                      masked: masked,
                      paise: false,
                    ),
                  ),
                  _Figure(
                    key: const Key('group_income'),
                    label: t('Received'),
                    value: formatAmount(
                      group.incomeMinor,
                      masked: masked,
                      paise: false,
                    ),
                  ),
                  _Figure(label: t('Count'), value: '${group.count}'),
                ],
              ),
            ),
          for (final tx in rows)
            Dismissible(
              key: Key('group_row_${tx.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.link_off),
              ),
              onDismissed: (_) => repo.remove(id, tx.id),
              child: InkWell(
                onTap: () => context.push('/transaction/${tx.id}'),
                child: rowBuilder(tx, masked: masked),
              ),
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                t('Nothing in this group yet.'),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      );
}

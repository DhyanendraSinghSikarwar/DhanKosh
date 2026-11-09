import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/groups_people_providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/transaction_groups/domain/tx_group.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Groups of transactions (F-39, FR-39-02): list with totals and a button to
/// make one.
class GroupsScreen extends ConsumerWidget {
  /// Creates the screen.
  const GroupsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await askGroupName(context, title: t('New group'));
    if (name == null || name.isEmpty) return;
    final id = await ref.read(txGroupRepositoryProvider).create(name);
    if (context.mounted) await context.push('/groups/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final groups = ref.watch(txGroupsProvider).value ?? const <TxGroup>[];
    return Scaffold(
      appBar: AppBar(title: Text(t('Groups'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('group_new'),
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(t('New group')),
      ),
      body: groups.isEmpty
          ? EmptyState(
              icon: Icons.folder_outlined,
              title: t('No groups yet'),
              hint: t('Group a trip or an event to see what it cost.'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final g in groups)
                  AppCard(
                    key: Key('group_${g.id}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    onTap: () => context.push('/groups/${g.id}'),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(g.name),
                      subtitle: Text(
                        '${g.count} ${g.count == 1 ? 'transaction' : 'transactions'}',
                      ),
                      trailing: Text(
                        formatAmount(
                          g.spentMinor,
                          masked: masked,
                          paise: false,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Asks for a group name; null when cancelled.
Future<String?> askGroupName(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('group_name_field'),
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: t('Goa trip')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          key: const Key('group_name_save'),
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: Text(t('Save')),
        ),
      ],
    ),
  );
}

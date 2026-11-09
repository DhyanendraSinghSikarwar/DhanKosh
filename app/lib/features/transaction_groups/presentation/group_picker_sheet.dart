import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/groups_people_providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/transaction_groups/domain/tx_group.dart';

/// Puts one transaction in groups (FR-39-04): tick groups, or make a new one.
Future<void> showGroupPicker(
  BuildContext context,
  WidgetRef ref,
  int txId,
) async {
  final repo = ref.read(txGroupRepositoryProvider);
  final groups = await ref.read(txGroupsProvider.future);
  final chosen = await repo.groupIdsOf(txId);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GroupPicker(
      repo: repo,
      txId: txId,
      groups: groups,
      chosen: chosen,
    ),
  );
}

class _GroupPicker extends StatefulWidget {
  const _GroupPicker({
    required this.repo,
    required this.txId,
    required this.groups,
    required this.chosen,
  });

  final TxGroupRepository repo;
  final int txId;
  final List<TxGroup> groups;
  final Set<int> chosen;

  @override
  State<_GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<_GroupPicker> {
  late final Set<int> _chosen = {...widget.chosen};
  late final List<TxGroup> _groups = [...widget.groups];
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    final id = await widget.repo.create(n);
    setState(() {
      _groups.insert(
        0,
        TxGroup(id: id, name: n, count: 0, spentMinor: 0, incomeMinor: 0),
      );
      _chosen.add(id);
      _name.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Groups'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final g in _groups)
                  CheckboxListTile(
                    key: Key('pick_group_${g.id}'),
                    contentPadding: EdgeInsets.zero,
                    value: _chosen.contains(g.id),
                    title: Text(g.name),
                    onChanged: (v) => setState(
                      () =>
                          v == true ? _chosen.add(g.id) : _chosen.remove(g.id),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('pick_group_new'),
                        controller: _name,
                        decoration: InputDecoration(hintText: t('New group')),
                      ),
                    ),
                    IconButton(
                      key: const Key('pick_group_add'),
                      icon: const Icon(Icons.add),
                      onPressed: _create,
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: const Key('pick_group_save'),
                    onPressed: () async {
                      await widget.repo.setGroupsOf(widget.txId, _chosen);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(t('Save')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

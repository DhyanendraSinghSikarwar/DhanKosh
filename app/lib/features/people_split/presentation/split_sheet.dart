import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/groups_people_providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/people_split/domain/people.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';

/// "Split with people" for one payment (FR-40-03): pick people, share equally
/// or by amount; each share becomes money that person owes you.
Future<void> showSplitSheet(
  BuildContext context,
  WidgetRef ref,
  LedgerTx tx,
) async {
  final repo = ref.read(peopleRepositoryProvider);
  final people = await repo.all();
  final existing = await repo.sharesOf(tx.id);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SplitSheet(
      tx: tx,
      repo: repo,
      people: people,
      existing: existing,
    ),
  );
}

class _SplitSheet extends StatefulWidget {
  const _SplitSheet({
    required this.tx,
    required this.repo,
    required this.people,
    required this.existing,
  });

  final LedgerTx tx;
  final PeopleRepository repo;
  final List<Person> people;
  final Map<int, int> existing;

  @override
  State<_SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends State<_SplitSheet> {
  late final Map<int, Person> _people;
  late final Set<int> _picked;
  final Map<int, TextEditingController> _amounts = {};
  final _newName = TextEditingController();
  var _equal = true;

  @override
  void initState() {
    super.initState();
    _people = {for (final p in widget.people) p.id: p};
    _picked = {...widget.existing.keys};
    _equal = widget.existing.isEmpty;
    widget.existing.forEach((id, minor) {
      _amounts[id] = TextEditingController(text: _rupees(minor));
    });
  }

  @override
  void dispose() {
    _newName.dispose();
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _rupees(int minor) =>
      minor % 100 == 0 ? '${minor ~/ 100}' : (minor / 100).toStringAsFixed(2);

  int get _total => widget.tx.amountMinor;

  /// Shares by person id under the current mode.
  Map<int, int> get _shares {
    final ids = _picked.toList()..sort();
    if (_equal) {
      final each = SplitMath.equalShares(_total, ids.length);
      return {for (final (i, id) in ids.indexed) id: each[i]};
    }
    return {
      for (final id in ids)
        id: parseMoney(_amounts[id]?.text ?? '')?.minor ?? 0,
    };
  }

  Future<void> _addPerson() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    final id = await widget.repo.addPerson(name);
    final all = await widget.repo.all();
    if (!mounted) return;
    setState(() {
      for (final p in all) {
        _people[p.id] = p;
      }
      _picked.add(id);
      _newName.clear();
    });
  }

  Future<void> _save() async {
    final shares = _shares..removeWhere((_, v) => v <= 0);
    await widget.repo.split(
      transactionId: widget.tx.id,
      label: 'Split: ${widget.tx.title}',
      shares: shares,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final shares = _shares;
    final yours = SplitMath.yourPart(_total, shares.values);
    final ok = yours >= 0 && shares.values.any((v) => v > 0);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Split with people'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                key: const Key('split_mode'),
                segments: [
                  ButtonSegment(value: true, label: Text(t('Equal'))),
                  ButtonSegment(value: false, label: Text(t('Amounts'))),
                ],
                selected: {_equal},
                onSelectionChanged: (v) => setState(() => _equal = v.first),
              ),
              for (final p in _people.values)
                CheckboxListTile(
                  key: Key('split_person_${p.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: _picked.contains(p.id),
                  title: Text(p.name),
                  secondary: !_equal && _picked.contains(p.id)
                      ? SizedBox(
                          width: 90,
                          child: TextField(
                            key: Key('split_amount_${p.id}'),
                            controller: _amounts.putIfAbsent(
                              p.id,
                              TextEditingController.new,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(hintText: '0'),
                          ),
                        )
                      : (_picked.contains(p.id) && shares[p.id] != null
                          ? Text(_rupees(shares[p.id]!))
                          : null),
                  onChanged: (v) => setState(
                    () => v == true ? _picked.add(p.id) : _picked.remove(p.id),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('split_new_name'),
                      controller: _newName,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(hintText: t('Add person')),
                    ),
                  ),
                  IconButton(
                    key: const Key('split_add_person'),
                    icon: const Icon(Icons.add),
                    onPressed: _addPerson,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${t('Your part')}: ${_rupees(yours < 0 ? 0 : yours)}'
                '${yours < 0 ? '  (${t('shares add up to more than the total')})' : ''}',
                key: const Key('split_yours'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (widget.existing.isNotEmpty)
                    TextButton(
                      key: const Key('split_clear'),
                      onPressed: () async {
                        await widget.repo.split(
                          transactionId: widget.tx.id,
                          label: '',
                          shares: const {},
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(t('Remove split')),
                    ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('split_save'),
                    onPressed: ok ? _save : null,
                    child: Text(t('Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

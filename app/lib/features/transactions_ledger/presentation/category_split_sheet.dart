import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/tx_part.dart';
import 'package:parser_core/parser_core.dart';

/// "Split into categories" (FR-41-02): two or more parts that add up to the
/// payment. Rupee payments only.
Future<void> showCategorySplitSheet(
  BuildContext context,
  WidgetRef ref,
  LedgerTx tx,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategorySplitSheet(tx: tx, ref: ref),
    );

class _Row {
  _Row(this.category, String amount)
      : amount = TextEditingController(text: amount);
  Category category;
  final TextEditingController amount;
}

class _CategorySplitSheet extends StatefulWidget {
  const _CategorySplitSheet({required this.tx, required this.ref});

  final LedgerTx tx;
  final WidgetRef ref;

  @override
  State<_CategorySplitSheet> createState() => _CategorySplitSheetState();
}

class _CategorySplitSheetState extends State<_CategorySplitSheet> {
  final _rows = <_Row>[];
  String? _error;

  static String _rupees(int minor) =>
      minor % 100 == 0 ? '${minor ~/ 100}' : (minor / 100).toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    if (widget.tx.parts.isEmpty) {
      _rows
        ..add(_Row(widget.tx.category, ''))
        ..add(_Row(Category.other, ''));
    } else {
      for (final p in widget.tx.parts) {
        _rows.add(_Row(p.category, _rupees(p.amountMinor)));
      }
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.amount.dispose();
    }
    super.dispose();
  }

  List<TxPart> get _parts => [
        for (final r in _rows)
          if ((parseMoney(r.amount.text)?.minor ?? 0) > 0)
            TxPart(r.category, parseMoney(r.amount.text)!.minor),
      ];

  int get _left =>
      widget.tx.amountMinor - _parts.fold<int>(0, (a, p) => a + p.amountMinor);

  Future<void> _save() async {
    final err = TxPart.validate(widget.tx.amountMinor, _parts);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    await widget.ref
        .read(transactionRepositoryProvider)
        .setParts(widget.tx.id, _parts);
    if (mounted) Navigator.pop(context);
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
                  t('Split into categories'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final (i, r) in _rows.indexed)
                  Row(
                    key: Key('part_row_$i'),
                    children: [
                      Expanded(
                        child: DropdownButton<Category>(
                          key: Key('part_cat_$i'),
                          isExpanded: true,
                          value: r.category,
                          items: [
                            for (final c in Category.values)
                              DropdownMenuItem(value: c, child: Text(c.label)),
                          ],
                          onChanged: (v) =>
                              setState(() => r.category = v ?? r.category),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          key: Key('part_amount_$i'),
                          controller: r.amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() => _error = null),
                          decoration: const InputDecoration(hintText: '0.00'),
                        ),
                      ),
                    ],
                  ),
                TextButton.icon(
                  key: const Key('part_add'),
                  onPressed: () =>
                      setState(() => _rows.add(_Row(Category.other, ''))),
                  icon: const Icon(Icons.add),
                  label: Text(t('Add part')),
                ),
                Text(
                  _left == 0
                      ? t('Adds up to the total')
                      : '${t('Left to place')}: ${_rupees(_left)}',
                  key: const Key('part_left'),
                ),
                if (_error != null)
                  Text(
                    t(_error!),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                Row(
                  children: [
                    if (widget.tx.parts.isNotEmpty)
                      TextButton(
                        key: const Key('part_clear'),
                        onPressed: () async {
                          await widget.ref
                              .read(transactionRepositoryProvider)
                              .setParts(widget.tx.id, const []);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(t('Remove split')),
                      ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('part_save'),
                      onPressed: _save,
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

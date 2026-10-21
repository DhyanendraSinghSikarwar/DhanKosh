import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:parser_core/parser_core.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Add, edit or confirm a regular payment or income (FR-12-03, FR-12-04).
///
/// [source] set with a null `manualId` is a detected item being confirmed:
/// saving stores a user item of the same name that replaces it.
class RecurringSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const RecurringSheet({this.source, super.key});

  /// Item to edit or confirm; null adds a new one.
  final Recurring? source;

  @override
  ConsumerState<RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends ConsumerState<RecurringSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _day;
  late bool _income;
  late bool _yearly;
  late int _month;
  late Category _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _name = TextEditingController(text: s?.name ?? '');
    _amount = TextEditingController(
      text: s == null ? '' : _rupees(s.amountMinor),
    );
    _day = TextEditingController(text: s == null ? '' : '${s.dayOfMonth}');
    _income = s?.income ?? false;
    _yearly = s?.yearly ?? false;
    _month = s?.nextDue.month ?? DateTime.now().month;
    _category = s?.category ?? Category.bills;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  static String _rupees(int minor) =>
      minor % 100 == 0 ? '${minor ~/ 100}' : (minor / 100).toStringAsFixed(2);

  RecurringDraft? _draft() {
    final minor = parseMoney(_amount.text)?.minor;
    final day = int.tryParse(_day.text.trim());
    if (minor == null || day == null) {
      setState(() => _error = 'Enter an amount and a day');
      return null;
    }
    final d = RecurringDraft(
      name: _name.text.trim(),
      amountMinor: minor,
      income: _income,
      frequency:
          _yearly ? RecurringFrequency.yearly : RecurringFrequency.monthly,
      dayOfMonth: day,
      month: _yearly ? _month : null,
      category: _category,
      accountId: widget.source?.accountId,
    );
    final err = d.validate();
    if (err != null) {
      setState(() => _error = err);
      return null;
    }
    return d;
  }

  Future<void> _save() async {
    final d = _draft();
    if (d == null) return;
    final repo = ref.read(recurringRepositoryProvider);
    final id = widget.source?.manualId;
    if (id == null) {
      await repo.add(d);
    } else {
      await repo.update(id, d);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref
        .read(recurringRepositoryProvider)
        .delete(widget.source!.manualId!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    final detected = s != null && s.manualId == null;
    final title = s == null
        ? 'Add regular payment'
        : detected
            ? 'Confirm detected payment'
            : 'Edit regular payment';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              key: const Key('rec-type'),
              segments: const [
                ButtonSegment(value: false, label: Text('Expense')),
                ButtonSegment(value: true, label: Text('Income')),
              ],
              selected: {_income},
              onSelectionChanged: (v) => setState(() => _income = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('rec-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              key: const Key('rec-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              key: const Key('rec-freq'),
              segments: const [
                ButtonSegment(value: false, label: Text('Monthly')),
                ButtonSegment(value: true, label: Text('Yearly')),
              ],
              selected: {_yearly},
              onSelectionChanged: (v) => setState(() => _yearly = v.first),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('rec-day'),
                    controller: _day,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Day (1-31)'),
                  ),
                ),
                if (_yearly) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const Key('rec-month'),
                      initialValue: _month,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: [
                        for (var i = 1; i <= 12; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(_months[i - 1]),
                          ),
                      ],
                      onChanged: (v) => setState(() => _month = v ?? _month),
                    ),
                  ),
                ],
              ],
            ),
            DropdownButtonFormField<Category>(
              key: const Key('rec-category'),
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in Category.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('rec-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (s?.manualId != null)
                  TextButton(
                    key: const Key('rec-delete'),
                    onPressed: _delete,
                    child: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('rec-save'),
                  onPressed: _save,
                  child: Text(detected ? 'Confirm' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

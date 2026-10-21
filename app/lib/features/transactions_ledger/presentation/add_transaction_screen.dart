// Riverpod's autoDispose provider types are not worth spelling out.
// ignore_for_file: specify_nonobvious_property_types
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:parser_core/parser_core.dart';

final _accountsProvider = StreamProvider.autoDispose<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchVisible(),
);

/// Manual entry: Spent / Received, amount, payee, account, category, date,
/// reference, note (FR-08-11; Transfer and OCR deferred).
class AddTransactionScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddState();
}

class _AddState extends ConsumerState<AddTransactionScreen> {
  final _amount = TextEditingController();
  final _payee = TextEditingController();
  final _ref = TextEditingController();
  final _note = TextEditingController();
  TransactionType _type = TransactionType.debit;
  Category _category = Category.other;
  int? _accountId;
  DateTime _when = DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    _ref.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => _when = DateTime(d.year, d.month, d.day, 12));
    }
  }

  Future<void> _save() async {
    final money = parseMoney(_amount.text);
    if (money == null || money.minor <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    String clean(TextEditingController c) => c.text.trim();
    final result = await ref.read(transactionRepositoryProvider).addManual(
          amountMinor: money.minor,
          type: _type,
          timestamp: _when.millisecondsSinceEpoch,
          accountId: _accountId,
          merchant: clean(_payee).isEmpty ? null : clean(_payee),
          category: _category,
          reference: clean(_ref).isEmpty ? null : clean(_ref),
          note: clean(_note).isEmpty ? null : clean(_note),
        );
    if (!mounted) return;
    final msg = switch (result.outcome) {
      IngestOutcome.merged => 'Merged with an existing transaction',
      IngestOutcome.flagged => 'Saved, needs review',
      _ => 'Transaction added',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/transactions');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(_accountsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TransactionType>(
            key: const Key('add_type'),
            segments: const [
              ButtonSegment(
                value: TransactionType.debit,
                label: Text('Spent'),
              ),
              ButtonSegment(
                value: TransactionType.credit,
                label: Text('Received'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('add_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('add_payee'),
            controller: _payee,
            decoration: const InputDecoration(labelText: 'Payee'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            key: const Key('add_account'),
            initialValue: _accountId,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              const DropdownMenuItem<int?>(child: Text('None')),
              for (final a in accounts)
                DropdownMenuItem<int?>(value: a.id, child: Text(a.label)),
            ],
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Category>(
            key: const Key('add_category'),
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in Category.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (v) => setState(() => _category = v ?? Category.other),
          ),
          const SizedBox(height: 12),
          ListTile(
            key: const Key('add_date'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            trailing: Text('${_when.day}/${_when.month}/${_when.year}'),
            onTap: _pickDate,
          ),
          TextField(
            key: const Key('add_reference'),
            controller: _ref,
            decoration: const InputDecoration(labelText: 'Reference'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('add_note'),
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('add_save'),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

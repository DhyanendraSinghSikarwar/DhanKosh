import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/presentation/account_tile.dart';
import 'package:parser_core/parser_core.dart';

/// Opens the add-account sheet (FR-13-05).
Future<void> showAddAccountSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddAccountSheet(),
    );

/// Bank, last 4, type, optional balance; "Already in your list." on a
/// duplicate (FR-13-05).
class AddAccountSheet extends ConsumerStatefulWidget {
  const AddAccountSheet({super.key});

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final TextEditingController _bank = TextEditingController();
  final TextEditingController _last4 = TextEditingController();
  final TextEditingController _balance = TextEditingController();
  AccountKind _kind = AccountKind.account;
  AccountType _type = AccountType.savings;
  String? _error;

  static const List<AccountType> _accountTypes = [
    AccountType.savings,
    AccountType.current,
    AccountType.salary,
    AccountType.wallet,
  ];

  @override
  void dispose() {
    _bank.dispose();
    _last4.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bank = _bank.text.trim();
    final last4 = _last4.text.trim();
    if (bank.isEmpty) return setState(() => _error = 'Enter the bank');
    if (!RegExp(r'^\d{4}$').hasMatch(last4)) {
      return setState(() => _error = 'Enter the last 4 digits');
    }
    int? minor;
    if (_balance.text.trim().isNotEmpty) {
      minor = parseMoney(_balance.text)?.minor;
      if (minor == null) return setState(() => _error = 'Invalid amount');
    }
    final isCard = _kind == AccountKind.card;
    final id = await ref.read(accountRepositoryProvider).create(
          NewAccount(
            kind: _kind,
            bankName: bank,
            last4: last4,
            accountType: isCard ? AccountType.creditCard : _type,
            balanceMinor: minor,
          ),
        );
    if (!mounted) return;
    if (id == null) return setState(() => _error = 'Already in your list.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isCard = _kind == AccountKind.card;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add account', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<AccountKind>(
              segments: const [
                ButtonSegment(
                  value: AccountKind.account,
                  label: Text('Account'),
                ),
                ButtonSegment(value: AccountKind.card, label: Text('Card')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('add_bank'),
              controller: _bank,
              decoration: const InputDecoration(labelText: 'Bank'),
            ),
            TextField(
              key: const Key('add_last4'),
              controller: _last4,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'Last 4 digits'),
            ),
            if (!isCard)
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final t in _accountTypes)
                    DropdownMenuItem(
                      value: t,
                      child: Text(accountTypeLabel(t)),
                    ),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
            TextField(
              key: const Key('add_balance'),
              controller: _balance,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isCard
                    ? 'Available limit (optional)'
                    : 'Balance (optional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('add_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('add_save'),
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

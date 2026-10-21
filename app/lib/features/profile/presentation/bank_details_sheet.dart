import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/profile/domain/bank_identity.dart';

/// Accounts with their saved unlock details (FR-27-15).
class BankDetailsListSheet extends ConsumerWidget {
  /// Creates the sheet.
  const BankDetailsListSheet({required this.accounts, super.key});

  /// Bank accounts to list.
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = {
      for (final b
          in ref.watch(bankIdentitiesProvider).value ?? <BankIdentity>[])
        b.accountId,
    };
    if (accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No bank accounts yet'),
      );
    }
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final a in accounts)
            ListTile(
              key: Key('bank-${a.id}'),
              title: Text(a.label),
              subtitle: Text(saved.contains(a.id) ? 'Saved' : 'Not set'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => BankDetailsSheet(account: a),
              ),
            ),
        ],
      ),
    );
  }
}

/// Edit the sealed unlock details of one account (FR-27-13, FR-27-16).
class BankDetailsSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const BankDetailsSheet({required this.account, super.key});

  /// Account being edited.
  final Account account;

  @override
  ConsumerState<BankDetailsSheet> createState() => _BankDetailsSheetState();
}

const _keys = [
  'customerId',
  'accountNumber',
  'ifsc',
  'name',
  'mobile',
  'email',
];

class _BankDetailsSheetState extends ConsumerState<BankDetailsSheet> {
  final _c = <String, TextEditingController>{
    for (final k in _keys) k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final b =
        await ref.read(bankIdentityRepositoryProvider).read(widget.account.id);
    {
      if (!mounted || b == null) return;
      _c['customerId']!.text = b.customerId;
      _c['accountNumber']!.text = b.accountNumber;
      _c['ifsc']!.text = b.ifsc;
      _c['name']!.text = b.name;
      _c['mobile']!.text = b.mobile;
      _c['email']!.text = b.email;
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(bankIdentityRepositoryProvider).save(
          BankIdentity(
            accountId: widget.account.id,
            customerId: _c['customerId']!.text,
            accountNumber: _c['accountNumber']!.text,
            ifsc: _c['ifsc']!.text,
            name: _c['name']!.text,
            mobile: _c['mobile']!.text,
            email: _c['email']!.text,
          ).normalised(),
        );
    ref.invalidate(bankIdentitiesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget f(String k, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: Key('bank-field-$k'),
            controller: _c[k],
            decoration: InputDecoration(labelText: label),
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.account.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Blank fields use your profile.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            f('customerId', 'Customer ID'),
            f('accountNumber', 'Account number'),
            f('ifsc', 'IFSC'),
            f('name', 'Name'),
            f('mobile', 'Mobile'),
            f('email', 'Email'),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('bank-save'),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

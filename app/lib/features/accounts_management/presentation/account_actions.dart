import 'package:flutter/material.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_admin_repository.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/accounts_management/presentation/account_tile.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/profile/domain/bank_identity_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';

Future<String?> _prompt(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  TextInputType? keyboard,
  String? removeLabel,
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('prompt_field'),
        controller: c,
        autofocus: true,
        keyboardType: keyboard,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        if (removeLabel != null)
          TextButton(
            key: const Key('prompt_remove'),
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(removeLabel),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          key: const Key('prompt_ok'),
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: Text(t('Save')),
        ),
      ],
    ),
  );
}

/// Rename; empty clears the nickname (FR-13-06).
Future<void> renameAccount(
  BuildContext context,
  AccountRepository repo,
  Account a,
) async {
  final v = await _prompt(
    context,
    title: t('Rename'),
    initial: a.nickname,
    hint: '${a.bankName} ••${a.last4}',
  );
  if (v != null) await repo.rename(a.id, v.isEmpty ? null : v);
}

/// Pick a type (FR-13-06).
Future<void> changeAccountType(
  BuildContext context,
  AccountRepository repo,
  Account a,
) async {
  final tt = await showDialog<AccountType>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(t('Account type')),
      children: [
        for (final tt in AccountType.values)
          SimpleDialogOption(
            key: Key('type_${tt.name}'),
            onPressed: () => Navigator.pop(ctx, tt),
            child: Text(accountTypeLabel(tt)),
          ),
      ],
    ),
  );
  if (tt != null) await repo.setType(a.id, tt);
}

/// Set or remove the typed balance (FR-13-06, FR-13-07).
Future<void> setBalance(
  BuildContext context,
  AccountRepository repo,
  Account a, {
  required int nowMs,
}) async {
  final v = await _prompt(
    context,
    title: t('Set balance'),
    hint: '0.00',
    keyboard: const TextInputType.numberWithOptions(decimal: true),
    removeLabel: a.manualBalanceMinor == null ? null : 'Remove',
  );
  if (v == null) return;
  if (v.isEmpty) {
    await repo.setManualBalance(a.id, null, null);
    return;
  }
  final m = parseMoney(v);
  if (m == null) return;
  await repo.setManualBalance(a.id, m.minor, nowMs);
}

/// Sets or clears the low-balance alert threshold (FR-13-23).
Future<void> setLowBalance(
  BuildContext context,
  AccountRepository repo,
  Account a,
) async {
  final v = await _prompt(
    context,
    title: t('Alert when balance is below'),
    hint: '0.00',
    keyboard: const TextInputType.numberWithOptions(decimal: true),
    removeLabel: a.lowBalanceMinor == null ? null : t('Turn off'),
  );
  if (v == null) return;
  if (v.isEmpty) {
    await repo.setLowBalance(a.id, null);
    return;
  }
  final m = parseMoney(v);
  if (m == null || m.minor <= 0) return;
  await repo.setLowBalance(a.id, m.minor);
}

/// Confirms, then deletes; true when deleted (FR-13-11).
Future<bool> confirmDelete(
  BuildContext context,
  AccountRepository repo,
  Account a,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete ${a.label}?'),
      content: Text(t('Transactions stay, without an account.')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          key: const Key('delete_confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t('Delete')),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await repo.delete(a.id);
  return true;
}

/// Picks an account to merge [a] into and merges after confirming
/// (FR-13-08); true when merged.
Future<bool> mergeAccountInto(
  BuildContext context,
  AccountAdminRepository admin,
  Account a,
) async {
  final all = [
    for (final x in await admin.all())
      if (x.id != a.id &&
          x.mergedIntoId == null &&
          !x.hidden &&
          x.kind == a.kind)
        x,
  ];
  if (!context.mounted) return false;
  final target = await showDialog<Account>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(t('Merge into')),
      children: [
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(t('No other account to merge into.')),
          ),
        for (final x in all)
          SimpleDialogOption(
            key: Key('merge_target_${x.id}'),
            onPressed: () => Navigator.pop(ctx, x),
            child: Text(x.label),
          ),
      ],
    ),
  );
  if (target == null || !context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Merge into ${target.label}?'),
      content: Text(t('Shown together. You can unmerge any time.')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          key: const Key('merge_confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t('Merge')),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await admin.merge(a.id, target.id);
  return true;
}

/// Delete with the option to remove its transactions (tombstoned) too;
/// unlock details are removed with the account (FR-13-11, FR-13-14).
/// True when deleted.
Future<bool> deleteAccountWithOptions(
  BuildContext context, {
  required Account account,
  required AccountRepository accounts,
  required TransactionRepository transactions,
  BankIdentityRepository? identities,
  AccountAdminRepository? ignoreWith,
}) async {
  final ignore = ignoreWith != null;
  var withTx = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('${ignore ? 'Ignore' : 'Delete'} ${account.label}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ignore
                  ? 'Its messages are dropped from now on.'
                  : 'Transactions stay, without an account.',
            ),
            CheckboxListTile(
              key: const Key('delete_with_tx'),
              contentPadding: EdgeInsets.zero,
              value: withTx,
              title: Text(t('Also delete its transactions')),
              onChanged: (v) => set(() => withTx = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Cancel')),
          ),
          FilledButton(
            key: const Key('delete_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ignore ? 'Ignore' : 'Delete'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  await ignoreWith?.ignore(account.id);
  if (withTx) {
    await transactions.deleteTransactions(
      await transactions.idsForAccount(account.id),
    );
  }
  await accounts.delete(account.id);
  try {
    await identities?.remove(account.id);
  } on Object {
    // Secure store unavailable: the account is gone either way.
  }
  return true;
}

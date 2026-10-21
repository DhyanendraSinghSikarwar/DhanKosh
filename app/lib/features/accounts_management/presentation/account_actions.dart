import 'package:flutter/material.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/accounts_management/presentation/account_tile.dart';

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
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('prompt_ok'),
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Save'),
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
    title: 'Rename',
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
  final t = await showDialog<AccountType>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Account type'),
      children: [
        for (final t in AccountType.values)
          SimpleDialogOption(
            key: Key('type_${t.name}'),
            onPressed: () => Navigator.pop(ctx, t),
            child: Text(accountTypeLabel(t)),
          ),
      ],
    ),
  );
  if (t != null) await repo.setType(a.id, t);
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
    title: 'Set balance',
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
      content: const Text('Transactions stay, without an account.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('delete_confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await repo.delete(a.id);
  return true;
}

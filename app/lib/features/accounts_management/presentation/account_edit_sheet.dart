import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/accounts_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/presentation/account_tile.dart';
import 'package:parser_core/parser_core.dart';

/// Colour swatches of the edit sheet (null clears).
const List<int> accountSwatches = [
  0xFF1E88E5,
  0xFF43A047,
  0xFFE53935,
  0xFFFB8C00,
  0xFF8E24AA,
  0xFF00897B,
  0xFF6D4C41,
  0xFF546E7A,
];

/// Network display name.
String networkLabel(CardNetwork n) => switch (n) {
      CardNetwork.rupay => 'RuPay',
      CardNetwork.mastercard => 'Mastercard',
      CardNetwork.amex => 'Amex',
      CardNetwork.unionpay => 'UnionPay',
      CardNetwork.jcb => 'JCB',
      _ => '${n.name[0].toUpperCase()}${n.name.substring(1)}',
    };

/// Markup percent text to bps; null when empty, `-1` when invalid (0..20).
int? parseMarkupBps(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v < 0 || v > 20) return -1;
  return (v * 100).round();
}

/// Opens the edit sheet for [account] (FR-13-06).
Future<void> showAccountEditSheet(
  BuildContext context,
  Account account, {
  Widget Function(Account)? unlockSheet,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          AccountEditSheet(account: account, unlockSheet: unlockSheet),
    );

/// Nickname, usage, type, network, debit-card link, colour, forex markup,
/// balance, unlock details, merged accounts (FR-13-06, FR-13-08, C8).
class AccountEditSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const AccountEditSheet({required this.account, this.unlockSheet, super.key});

  final Account account;

  /// Statement unlock form supplied by the app shell (profile feature).
  final Widget Function(Account)? unlockSheet;

  @override
  ConsumerState<AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends ConsumerState<AccountEditSheet> {
  late final _nick = TextEditingController(text: widget.account.nickname);
  final _markup = TextEditingController();
  final _balance = TextEditingController();
  late AccountUsage _usage = widget.account.usage;
  late AccountType? _type = widget.account.accountType;
  late CardNetwork? _network = widget.account.cardNetwork;
  late int? _color = widget.account.colorArgb;
  late int? _link = widget.account.linkedAccountId;
  bool _removeBalance = false;
  String? _error;
  List<Account> _banks = const [];
  List<Account> _children = const [];

  Account get _a => widget.account;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final admin = ref.read(accountAdminRepositoryProvider);
    final all = await admin.all();
    final bps = await admin.forexMarkupBps(_a.id);
    final kids = await admin.mergedChildren(_a.id);
    if (!mounted) return;
    setState(() {
      _banks = [
        for (final b in all)
          if (b.kind == AccountKind.account &&
              b.id != _a.id &&
              b.mergedIntoId == null)
            b,
      ];
      _children = kids;
      if (bps != null) _markup.text = (bps / 100).toString();
    });
  }

  Future<void> _save() async {
    final bps = parseMarkupBps(_markup.text);
    if (bps == -1) {
      setState(() => _error = 'Markup must be 0 to 20%');
      return;
    }
    final repo = ref.read(accountRepositoryProvider);
    final admin = ref.read(accountAdminRepositoryProvider);
    await repo.rename(_a.id, _nick.text);
    await admin.setColor(_a.id, _color);
    await admin.setUsage(_a.id, _usage);
    await repo.setType(_a.id, _type);
    if (_a.kind == AccountKind.card) {
      await admin.setNetwork(_a.id, _network);
      final before = await admin.forexMarkupBps(_a.id);
      await admin.setForexMarkupBps(_a.id, bps);
      if (before != bps) await ref.read(forexRepositoryProvider).recompute();
    }
    await admin.setLinkedAccount(
      _a.id,
      _type == AccountType.debitCard ? _link : null,
    );
    if (_removeBalance) {
      await repo.setManualBalance(_a.id, null, null);
    } else if (_balance.text.trim().isNotEmpty) {
      final m = parseMoney(_balance.text.trim());
      if (m == null) {
        setState(() => _error = 'Enter a valid amount');
        return;
      }
      await repo.setManualBalance(
        _a.id,
        m.minor,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    ref.invalidate(openGapsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isCard = _a.kind == AccountKind.card;
    final types = isCard
        ? const [
            AccountType.creditCard,
            AccountType.debitCard,
            AccountType.prepaidCard,
          ]
        : [
            for (final t in AccountType.values)
              if (t != AccountType.creditCard &&
                  t != AccountType.debitCard &&
                  t != AccountType.prepaidCard)
                t,
          ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('edit_nickname'),
              controller: _nick,
              decoration: InputDecoration(
                labelText: 'Nickname',
                hintText: '${_a.bankName} ••${_a.last4}',
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<AccountUsage>(
              key: const Key('edit_usage'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AccountUsage.personal,
                  label: Text('Personal'),
                ),
                ButtonSegment(
                  value: AccountUsage.business,
                  label: Text('Business'),
                ),
              ],
              selected: {_usage},
              onSelectionChanged: (s) => setState(() => _usage = s.first),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final t in types)
                  ChoiceChip(
                    key: Key('edit_type_${t.name}'),
                    label: Text(accountTypeLabel(t)),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            if (isCard) ...[
              const SizedBox(height: 12),
              Text('Network', style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in CardNetwork.values)
                    ChoiceChip(
                      key: Key('edit_network_${n.name}'),
                      label: Text(networkLabel(n)),
                      selected: _network == n,
                      onSelected: (s) =>
                          setState(() => _network = s ? n : null),
                    ),
                ],
              ),
              TextField(
                key: const Key('edit_markup'),
                controller: _markup,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Forex markup %',
                  helperText: 'Include GST: 3.5% + 18% = 4.13%.',
                ),
              ),
            ],
            if (_type == AccountType.debitCard && _banks.isNotEmpty)
              DropdownButtonFormField<int>(
                key: const Key('edit_link'),
                initialValue: _banks.any((b) => b.id == _link) ? _link : null,
                hint: const Text('Linked bank account'),
                items: [
                  for (final b in _banks)
                    DropdownMenuItem(value: b.id, child: Text(b.label)),
                ],
                onChanged: (v) => setState(() => _link = v),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('edit_color_none'),
                  label: const Text('No colour'),
                  selected: _color == null,
                  onSelected: (_) => setState(() => _color = null),
                ),
                for (final c in accountSwatches)
                  GestureDetector(
                    key: Key('edit_color_$c'),
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(c),
                      child: _color == c
                          ? const Icon(Icons.check, size: 16)
                          : null,
                    ),
                  ),
              ],
            ),
            TextField(
              key: const Key('edit_balance'),
              controller: _balance,
              enabled: !_removeBalance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: isCard ? 'Available limit' : 'Balance',
                hintText: '0.00',
              ),
            ),
            if (_a.manualBalanceMinor != null)
              CheckboxListTile(
                key: const Key('edit_remove_balance'),
                contentPadding: EdgeInsets.zero,
                value: _removeBalance,
                title: const Text('Remove the balance I set'),
                onChanged: (v) => setState(() => _removeBalance = v ?? false),
              ),
            if (_children.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Merged accounts',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final c in _children)
                ListTile(
                  key: Key('merged_${c.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.label),
                  trailing: TextButton(
                    key: Key('unmerge_${c.id}'),
                    onPressed: () async {
                      await ref
                          .read(accountAdminRepositoryProvider)
                          .unmerge(c.id);
                      await _load();
                    },
                    child: const Text('Unmerge'),
                  ),
                ),
            ],
            if (widget.unlockSheet != null && !isCard)
              TextButton.icon(
                key: const Key('edit_unlock'),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Statement unlock details'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => widget.unlockSheet!(_a),
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('edit_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('edit_save'),
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

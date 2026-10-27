import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/accounts_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/untracked_gap.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:intl/intl.dart';
import 'package:parser_core/parser_core.dart';

/// Untracked-change card of one account (FR-13-15): Add transaction, Assign
/// to a message-created row, Ignore.
class GapCard extends ConsumerStatefulWidget {
  /// Creates the card for [gap].
  const GapCard({required this.gap, required this.account, super.key});

  final UntrackedGap gap;
  final Account account;

  @override
  ConsumerState<GapCard> createState() => _GapCardState();
}

class _GapCardState extends ConsumerState<GapCard> {
  List<List<LedgerTx>> _candidates = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final c =
        await ref.read(untrackedGapServiceProvider).candidates(widget.gap);
    if (mounted) setState(() => _candidates = c);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gap;
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final theme = Theme.of(context);
    final amt = formatAmount(g.deltaMinor.abs(), masked: masked);
    final what = g.card
        ? (g.moneyLeft ? '$amt of limit used' : '$amt of limit freed')
        : (g.moneyLeft ? '$amt left' : '$amt came in');
    final fmt = DateFormat('d MMM');
    final svc = ref.read(untrackedGapServiceProvider);
    return AppCard(
      key: Key('gap_${g.key}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Untracked change',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.tertiary),
          ),
          Text(
            '$what with no message, '
            '${fmt.format(DateTime.fromMillisecondsSinceEpoch(g.fromTime))} to '
            '${fmt.format(DateTime.fromMillisecondsSinceEpoch(g.toTime))}',
            key: const Key('gap_summary'),
          ),
          for (var i = 0; i < _candidates.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Looks like: ${_candidates[i].map((t) => t.title).join(' + ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    key: Key('gap_assign_$i'),
                    onPressed: () async {
                      await svc.assign(g, _candidates[i]);
                      ref.invalidate(openGapsProvider);
                    },
                    child: const Text('Assign'),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('gap_ignore'),
                onPressed: () async {
                  await svc.ignore(g);
                  ref.invalidate(openGapsProvider);
                },
                child: const Text('Ignore'),
              ),
              FilledButton(
                key: const Key('gap_add'),
                onPressed: () => showGapExplainSheet(context, g),
                child: const Text('Add transaction'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the prefilled Add transaction sheet for [gap].
Future<void> showGapExplainSheet(BuildContext context, UntrackedGap gap) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GapExplainSheet(gap: gap),
    );

/// Payment / Transfer to my account / Money received, amount and time
/// prefilled from the gap (memory 13 3.8). Saves through the ledger repo.
class GapExplainSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const GapExplainSheet({required this.gap, super.key});

  final UntrackedGap gap;

  @override
  ConsumerState<GapExplainSheet> createState() => _GapExplainSheetState();
}

class _GapExplainSheetState extends ConsumerState<GapExplainSheet> {
  late GapPrefill _p = GapPrefill.of(widget.gap);
  late GapChoice _choice = _p.choice;
  final _what = TextEditingController();
  int? _other;
  List<Account> _accounts = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final svc = ref.read(untrackedGapServiceProvider);
    final last = await svc.lastChoice(widget.gap.accountId);
    final all = await ref.read(accountRepositoryProvider).watchVisible().first;
    if (!mounted) return;
    setState(() {
      _p = GapPrefill.of(widget.gap, last: last);
      _choice = _p.choice;
      _accounts = [
        for (final a in all)
          if (a.id != widget.gap.accountId) a,
      ];
    });
  }

  String _label(GapChoice c) => switch (c) {
        GapChoice.payment => 'Payment',
        GapChoice.transfer => 'Transfer to my account',
        GapChoice.received => 'Money received',
      };

  Future<void> _save() async {
    final txs = ref.read(transactionRepositoryProvider);
    final note = _what.text.trim().isEmpty ? null : _what.text.trim();
    switch (_choice) {
      case GapChoice.payment:
        await txs.addManual(
          amountMinor: _p.amountMinor,
          type: TransactionType.debit,
          timestamp: _p.time,
          accountId: _p.accountId,
          merchant: note,
        );
      case GapChoice.received:
        await txs.addManual(
          amountMinor: _p.amountMinor,
          type: TransactionType.credit,
          timestamp: _p.time,
          accountId: _p.accountId,
          merchant: note,
        );
      case GapChoice.transfer:
        await txs.addOwnTransfer(
          fromAccountId: _p.outgoing ? _p.accountId : _other,
          toAccountId: _p.outgoing ? _other : _p.accountId,
          amountMinor: _p.amountMinor,
          timestamp: _p.time,
          note: note,
        );
    }
    await ref
        .read(untrackedGapServiceProvider)
        .rememberChoice(_p.accountId, _choice);
    ref.invalidate(openGapsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatAmount(_p.amountMinor, masked: masked),
              key: const Key('gap_amount'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _p.choices)
                  ChoiceChip(
                    key: Key('gap_choice_${c.name}'),
                    label: Text(_label(c)),
                    selected: _choice == c,
                    onSelected: (_) => setState(() => _choice = c),
                  ),
              ],
            ),
            if (_choice == GapChoice.transfer)
              DropdownButtonFormField<int>(
                key: const Key('gap_other'),
                initialValue: _other,
                hint: Text(_p.outgoing ? 'To account' : 'From account'),
                items: [
                  for (final a in _accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.label)),
                ],
                onChanged: (v) => setState(() => _other = v),
              ),
            TextField(
              key: const Key('gap_what'),
              controller: _what,
              decoration: InputDecoration(
                labelText: _choice == GapChoice.transfer ? 'Note' : 'Payee',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('gap_save'),
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

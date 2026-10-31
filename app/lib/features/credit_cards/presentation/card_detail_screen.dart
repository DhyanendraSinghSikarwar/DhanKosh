import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/cards_providers.dart';
import 'package:hisaab/app/di/home_cards_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_view.dart';
import 'package:hisaab/features/credit_cards/presentation/card_due_format.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

/// Card page `/cards/:id`: statement balance, unbilled, minimum due, limit,
/// available limit, upcoming payments, card transactions and statement
/// history, with an Edit mode that overrides the four figures
/// (FR-14-24..27).
class CardDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for the card with account id [cardId].
  const CardDetailScreen({required this.cardId, super.key});

  /// Account id of the card.
  final int cardId;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  static const _fields = ['stmt', 'unbilled', 'min', 'limit'];
  static const _labels = {
    'stmt': 'Statement balance',
    'unbilled': 'Unbilled amount',
    'min': 'Minimum due',
    'limit': 'Credit limit',
  };

  bool _editing = false;
  final Map<String, TextEditingController> _c = {
    for (final f in _fields) f: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _text(int? minor) => minor == null
      ? ''
      : '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

  int? _cur(CardView v, String f) => switch (f) {
        'stmt' => v.card.billedMinor,
        'unbilled' => v.card.unbilledMinor,
        'min' => v.card.minDueMinor,
        _ => v.limitMinor,
      };

  void _startEdit(CardView v) {
    for (final f in _fields) {
      _c[f]!.text = _text(_cur(v, f));
    }
    setState(() => _editing = true);
  }

  /// Null when empty, -1 when invalid.
  int? _value(String f) {
    final t = _c[f]!.text.trim();
    if (t.isEmpty) return null;
    final m = parseMoney(t);
    return m == null || m.minor < 0 ? -1 : m.minor;
  }

  Future<void> _save(CardView v) async {
    if (_fields.any((f) => _value(f) == -1)) return;
    final card = v.card;
    await ref.read(cardDueActionsProvider).saveEdit(
          card,
          calculated: card.position.calculated ?? card.position,
          billedMinor: _value('stmt'),
          minDueMinor: _value('min'),
          unbilledMinor: _value('unbilled'),
          outstandingMinor: card.outstandingMinor,
          dueEpochDay: card.dueDay,
        );
    if (!mounted) return;
    await saveCardLimitOverride(ref, v, _value('limit'));
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _reset(CardView v) async {
    await ref.read(cardDueActionsProvider).resetAll(v.card);
    if (!mounted) return;
    await saveCardLimitOverride(ref, v, null);
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(cardViewProvider(widget.cardId));
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    if (v == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Card')),
        body: const EmptyState(
          icon: Icons.credit_card_outlined,
          title: 'Card not found',
          hint: 'It may have been merged or hidden.',
        ),
      );
    }
    final card = v.card;
    final now = DateTime.now().millisecondsSinceEpoch;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('card_detail_back'),
            onPressed: () => context.pop(),
            child: const Text('‹ Back'),
          ),
        ),
        centerTitle: true,
        title: Text(
          card.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            key: const Key('card_detail_edit'),
            onPressed: _editing
                ? () => setState(() => _editing = false)
                : () => _startEdit(v),
            child: Text(_editing ? 'Cancel' : 'Edit'),
          ),
        ],
      ),
      body: ListView(
        key: const Key('card_detail'),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          _Hero(view: v, masked: masked, nowMs: now),
          _AutoNote(view: v),
          AppCard(
            child: _editing ? _editForm(v) : _Overview(view: v, masked: masked),
          ),
          if (!_editing) ...[
            const _Heading('Upcoming payments'),
            _Upcoming(view: v, masked: masked),
            const _Heading('Transactions'),
            _Txs(cardId: card.id, masked: masked),
            const _Heading('Statement history'),
            _History(cardId: card.id, masked: masked),
          ],
        ],
      ),
    );
  }

  Widget _editForm(CardView v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in _fields) ...[
          TextField(
            key: Key('card_edit_$f'),
            controller: _c[f],
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _labels[f],
              prefixText: '₹ ',
              errorText: _value(f) == -1 ? 'Enter an amount' : null,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            if (v.edited)
              TextButton(
                key: const Key('card_edit_reset'),
                onPressed: () => _reset(v),
                child: const Text('Reset all'),
              ),
            const Spacer(),
            TextButton(
              key: const Key('card_edit_cancel'),
              onPressed: () => setState(() => _editing = false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('card_edit_save'),
              onPressed:
                  _fields.any((f) => _value(f) == -1) ? null : () => _save(v),
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditedTag extends StatelessWidget {
  const _EditedTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'edited',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.view, required this.masked, required this.nowMs});

  final CardView view;
  final bool masked;
  final int nowMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = view.card;
    final due = c.dueDay;
    final owed = view.dueMinor;
    final used = view.usedFraction;
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppIcons.violet.withValues(alpha: 0.22),
              scheme.surfaceContainer,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SectionLabel(c.name),
                  if (view.edited) ...[
                    const SizedBox(width: 6),
                    const _EditedTag(key: Key('card_detail_edited')),
                  ],
                  const Spacer(),
                  Text('••${c.last4}', style: MockText.small(context)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                cardWhole(owed, masked: masked),
                key: const Key('card_detail_balance'),
                style: MockText.big(context),
              ),
              Text(
                owed > 0 && due != null
                    ? 'Statement balance · due ${cardDate(due)}'
                    : 'No dues',
                style: MockText.small(context),
              ),
              if (used != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: used,
                    minHeight: 7,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: AppIcons.mint,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${(used * 100).round()}% used',
                        style: MockText.small(context),
                      ),
                    ),
                    Text(
                      'Limit ${cardWhole(view.limitMinor!, masked: masked)}',
                      style: MockText.small(context),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoNote extends StatelessWidget {
  const _AutoNote({required this.view});

  final CardView view;

  @override
  Widget build(BuildContext context) {
    final day = view.card.position.statementDay;
    final manual = view.card.position.edited;
    final text = manual
        ? 'Edited by you. Edit to change or reset.'
        : day == null
            ? 'No statement yet. Figures come from your transactions.'
            : 'Filled from statement dated ${cardDateYear(day)}. '
                'Edit to override.';
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              manual ? 'Edited' : 'Auto',
              style: TextStyle(fontSize: 10, color: scheme.primary),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              key: const Key('card_detail_note'),
              style: MockText.small(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.view, required this.masked});

  final CardView view;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final p = view.card.position;
    final line = Theme.of(context).colorScheme.outlineVariant;
    Widget row(String k, int? v, {required bool edited, Key? key}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: Row(
            children: [
              Text(k, style: MockText.small(context).copyWith(fontSize: 14)),
              if (edited) const _EditedTag(),
              const Spacer(),
              Text(
                v == null ? '–' : cardWhole(v, masked: masked),
                key: key,
                style: MockText.body(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Overview'),
        const SizedBox(height: 2),
        row(
          'Statement balance',
          view.card.billedMinor ?? view.card.outstandingMinor,
          edited: p.billedEdited || p.outstandingEdited,
          key: const Key('card_ov_stmt'),
        ),
        row(
          'Unbilled amount',
          view.card.unbilledMinor,
          edited: p.unbilledEdited,
          key: const Key('card_ov_unbilled'),
        ),
        row(
          'Minimum due',
          view.card.minDueMinor,
          edited: p.minDueEdited,
          key: const Key('card_ov_min'),
        ),
        row(
          'Credit limit',
          view.limitMinor,
          edited: view.limitEdited,
          key: const Key('card_ov_limit'),
        ),
        row(
          'Available limit',
          view.availableMinor,
          edited: false,
          key: const Key('card_ov_available'),
        ),
      ],
    );
  }
}

class _Upcoming extends ConsumerWidget {
  const _Upcoming({required this.view, required this.masked});

  final CardView view;
  final bool masked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = view.card;
    final due = c.dueDay;
    final owed = view.dueMinor;
    if (due == null || owed <= 0 || c.paid) {
      return AppCard(
        child: Text(
          c.paid ? 'Marked paid' : 'Nothing due',
          key: const Key('card_detail_nodue'),
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          IconAmountRow(
            icon: AppIcons.bills,
            title: 'Statement due',
            subtitle: cardDate(due),
            amount: cardWhole(owed, masked: masked),
            divider: c.minDueMinor != null,
          ),
          if (c.minDueMinor != null)
            IconAmountRow(
              icon: AppIcons.alerts,
              title: 'Minimum due',
              subtitle: cardDate(due),
              amount: cardWhole(c.minDueMinor!, masked: masked),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('card_detail_paid'),
              onPressed: () => ref.read(cardDueActionsProvider).markPaid(c),
              child: const Text('Mark paid'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Txs extends ConsumerWidget {
  const _Txs({required this.cardId, required this.masked});

  final int cardId;
  final bool masked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs =
        ref.watch(cardTransactionsProvider(cardId)).value ?? const <LedgerTx>[];
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          if (txs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No card transactions yet'),
            ),
          for (final (i, t) in txs.indexed)
            InkWell(
              key: Key('card_tx_${t.id}'),
              onTap: () => context.push('/transaction/${t.id}'),
              child: IconAmountRow(
                icon: AppIcon(
                  Icons.shopping_bag_outlined,
                  i.isEven ? AppIcons.blue : AppIcons.amber,
                ),
                title: t.merchant ?? t.bankName,
                subtitle: '${t.category.label} · '
                    '${cardDate(CardDay.ofMs(t.timestamp))}',
                amount: cardWhole(t.amountMinor, masked: masked),
                amountSize: 15,
                divider: true,
              ),
            ),
          Center(
            child: TextButton(
              key: const Key('card_detail_all_txs'),
              onPressed: () => context.go('/transactions'),
              child: const Text('All card transactions ›'),
            ),
          ),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.cardId, required this.masked});

  final int cardId;
  final bool masked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hist =
        ref.watch(cardInsightsProvider(cardId)).value?.history ?? const [];
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          if (hist.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No statements yet'),
            ),
          for (var i = 0; i < hist.length; i++)
            KeyedSubtree(
              key: Key('card_hist_$i'),
              child: IconAmountRow(
                divider: i < hist.length - 1,
                title: hist[i].statementDay == null
                    ? 'Statement'
                    : cardDateYear(hist[i].statementDay!),
                subtitle:
                    hist[i].lateRisk ? 'Late risk' : hist[i].payment.label,
                amount: hist[i].totalDueMinor == null
                    ? '–'
                    : cardWhole(hist[i].totalDueMinor!, masked: masked),
                amountSize: 15,
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_cards_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/features/credit_cards/domain/card_view.dart';
import 'package:hisaab/features/credit_cards/presentation/card_due_format.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';

/// Home Credit cards card: total due and a row per card of the shared Book
/// with due amount, due date and a limit-used bar. A row opens the card
/// page `/cards/:id` (FR-14-12, FR-14-24, FR-14-25). Empty when there is no
/// card.
class CardsHomeStrip extends ConsumerWidget {
  /// Creates the strip.
  const CardsHomeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(homeCardsProvider);
    if (cards.isEmpty) return const SizedBox.shrink();
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final theme = Theme.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;
    final total =
        cards.fold<int>(0, (s, v) => s + (v.card.paid ? 0 : v.dueMinor));
    return AppCard(
      key: const Key('home_cards_strip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('home_cards_header'),
            onTap: () => context.push('/cards'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Credit cards',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  total == 0
                      ? 'No dues'
                      : 'Total due ${cardMoney(total, masked: masked)}',
                  key: const Key('home_cards_total'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          for (final v in cards) _CardRow(view: v, masked: masked, nowMs: now),
        ],
      ),
    );
  }
}

class _CardRow extends ConsumerWidget {
  const _CardRow({
    required this.view,
    required this.masked,
    required this.nowMs,
  });

  final CardView view;
  final bool masked;
  final int nowMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = view.card;
    final due = c.dueDay;
    final owed = view.dueMinor;
    final used = view.usedFraction;
    final limit = view.limitMinor;
    final soon =
        !c.paid && owed > 0 && due != null && daysToDue(due, nowMs) <= 7;
    final sub = [
      if (c.paid)
        'Paid'
      else if (owed > 0 && due != null)
        'Due ${cardDate(due)}'
      else
        'No dues',
      if (limit != null) 'limit ${cardMoney(limit, masked: masked)}',
    ].join(' · ');
    return InkWell(
      key: Key('home_card_${c.id}'),
      onTap: () => context.push('/cards/${c.id}'),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Row(
              children: [
                const IconBadge(AppIcons.cards),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.name} ••${c.last4}'),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  c.paid ? 'Paid' : cardMoney(owed, masked: masked),
                  key: Key('home_card_due_${c.id}'),
                  style: theme.textTheme.titleSmall,
                ),
                if (soon)
                  TextButton(
                    key: Key('home_card_paid_${c.id}'),
                    onPressed: () =>
                        ref.read(cardDueActionsProvider).markPaid(c),
                    child: const Text('Mark paid'),
                  )
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
            if (used != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                key: Key('home_card_used_${c.id}'),
                value: used,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: used > 0.4 ? AppIcons.amber : AppIcons.mint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

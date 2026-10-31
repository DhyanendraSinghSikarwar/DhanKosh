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
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// Home Credit cards card: total due and a row per card of the shared Book
/// with due amount, due date and a limit-used bar. A row opens the card
/// page `/cards/:id` (FR-14-12, FR-14-24, FR-14-25). Empty when there is no
/// card.
class CardsHomeStrip extends ConsumerStatefulWidget {
  /// Creates the strip.
  const CardsHomeStrip({super.key});

  @override
  ConsumerState<CardsHomeStrip> createState() => _CardsHomeStripState();
}

class _CardsHomeStripState extends ConsumerState<CardsHomeStrip> {
  bool _info = false;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(homeCardsProvider);
    if (cards.isEmpty) return const SizedBox.shrink();
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final total =
        cards.fold<int>(0, (s, v) => s + (v.card.paid ? 0 : v.dueMinor));
    return AppCard(
      key: const Key('home_cards_strip'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('home_cards_header'),
            onTap: () => context.push('/cards'),
            child: CardHeader(
              'Credit cards',
              info: InfoDot(
                key: const Key('home_cards_info'),
                onTap: () => setState(() => _info = !_info),
              ),
              trailing: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: total == 0 ? 'No dues' : 'Total due '),
                    if (total != 0)
                      TextSpan(
                        text: cardWhole(total, masked: masked),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
                key: const Key('home_cards_total'),
                style: MockText.small(context),
              ),
            ),
          ),
          if (_info)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Read from your latest statements. Open a card to see '
                'unbilled spends and edit anything that looks off.',
                style: MockText.small(context),
              ),
            ),
          const SizedBox(height: 6),
          for (final (i, v) in cards.indexed)
            _CardRow(view: v, masked: masked, nowMs: now, first: i == 0),
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
    required this.first,
  });

  final CardView view;
  final bool masked;
  final int nowMs;
  final bool first;

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
      if (limit != null) 'limit ${cardCompact(limit, masked: masked)}',
    ].join(' · ');
    return InkWell(
      key: Key('home_card_${c.id}'),
      onTap: () => context.push('/cards/${c.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(AppIcons.cards),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: c.name),
                            TextSpan(
                              text: ' ••${c.last4}',
                              style: MockText.small(context),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MockText.body(context),
                      ),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MockText.small(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      c.paid ? 'Paid' : cardWhole(owed, masked: masked),
                      key: Key('home_card_due_${c.id}'),
                      style: MockText.mid(context),
                    ),
                    if (soon)
                      InkWell(
                        key: Key('home_card_paid_${c.id}'),
                        onTap: () =>
                            ref.read(cardDueActionsProvider).markPaid(c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'Mark paid',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        '›',
                        style: MockText.body(
                          context,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (used != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  key: Key('home_card_used_${c.id}'),
                  value: used,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: used > 0.4 ? AppIcons.amber : AppIcons.mint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

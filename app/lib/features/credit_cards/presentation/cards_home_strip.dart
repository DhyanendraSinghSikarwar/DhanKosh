import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/cards_providers.dart';
import 'package:hisaab/features/credit_cards/presentation/card_due_format.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Home cards strip: total owed and a row per card; opens `/cards`
/// (FR-14-12). Empty when there is no card.
class CardsHomeStrip extends ConsumerWidget {
  /// Creates the strip.
  const CardsHomeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(activeCardsProvider).value ?? const [];
    if (cards.isEmpty) return const SizedBox.shrink();
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final theme = Theme.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;
    final total = cards.fold<int>(0, (s, c) => s + (c.paid ? 0 : c.owedMinor));
    return AppCard(
      key: const Key('home_cards_strip'),
      onTap: () => context.push('/cards'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Card dues', style: theme.textTheme.titleMedium),
              ),
              Text(
                total == 0 ? 'No dues' : cardMoney(total, masked: masked),
                key: const Key('home_cards_total'),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          for (final c in cards) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('${c.name} ••${c.last4}')),
                Flexible(
                  child: Text(
                    c.paid
                        ? 'Paid'
                        : c.owedMinor > 0 && c.dueDay != null
                            ? '${cardMoney(c.owedMinor, masked: masked)} · '
                                '${dueLabel(daysToDue(c.dueDay!, now))}'
                            : c.owedMinor > 0
                                ? cardMoney(c.owedMinor, masked: masked)
                                : 'No dues',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

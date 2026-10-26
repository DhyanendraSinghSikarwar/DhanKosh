import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/cards_providers.dart';
import 'package:hisaab/features/credit_cards/domain/card_insights.dart';
import 'package:hisaab/features/credit_cards/presentation/card_due_format.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Under a card: this-cycle spend, late-payment risk and statement history
/// (FR-14-18..22).
class CardInsightsSection extends ConsumerWidget {
  /// Creates the section for card [cardId].
  const CardInsightsSection({
    required this.cardId,
    required this.masked,
    super.key,
  });

  /// Account id of the card.
  final int cardId;

  /// Hide amounts.
  final bool masked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ins = ref.watch(cardInsightsProvider(cardId)).value;
    if (ins == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    if (ins.cycleSpendMinor == null && ins.history.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppCard(
      key: Key('card_insights_$cardId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ins.lateRisk)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Chip(
                key: Key('card_late_$cardId'),
                avatar: Icon(
                  Icons.warning_amber_outlined,
                  color: theme.colorScheme.error,
                ),
                label: const Text('Late payment risk'),
              ),
            ),
          if (ins.cycleSpendMinor != null)
            Row(
              children: [
                const Expanded(child: Text('Spent this cycle')),
                Text(
                  cardMoney(ins.cycleSpendMinor!, masked: masked),
                  key: Key('card_cycle_$cardId'),
                ),
              ],
            ),
          if (ins.history.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Statements', style: theme.textTheme.titleSmall),
            for (var i = 0; i < ins.history.length; i++)
              _Entry(
                key: Key('card_stmt_${cardId}_$i'),
                e: ins.history[i],
                masked: masked,
              ),
          ],
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.e, required this.masked, super.key});

  final StatementEntry e;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = [
      if (e.statementDay != null) cardDate(e.statementDay!),
      if (e.dueDay != null) 'due ${cardDate(e.dueDay!)}',
      if (e.minDueMinor != null)
        'min ${cardMoney(e.minDueMinor!, masked: masked)}',
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        e.totalDueMinor == null
            ? 'Total not known'
            : cardMoney(e.totalDueMinor!, masked: masked),
      ),
      subtitle: Text(parts.join(' · ')),
      trailing: Text(
        e.lateRisk
            ? 'Late risk'
            : '${e.payment.label}${e.verified && !e.markedPaid ? ' ✓' : ''}',
        style: TextStyle(
          color: e.lateRisk ? theme.colorScheme.error : null,
        ),
      ),
    );
  }
}

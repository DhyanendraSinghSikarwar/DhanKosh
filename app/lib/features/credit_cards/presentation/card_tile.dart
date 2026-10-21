import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/presentation/card_due_format.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// One card: position lines and due actions (FR-14-12, FR-14-13).
class CardTile extends StatelessWidget {
  /// Creates a tile.
  const CardTile({
    required this.card,
    required this.masked,
    required this.nowMs,
    required this.onMarkPaid,
    required this.onUndo,
    required this.onEdit,
    super.key,
  });

  /// Card with its position.
  final CardLimit card;

  /// Hide amounts.
  final bool masked;

  /// Clock for the due label.
  final int nowMs;

  /// Mark the bill paid.
  final VoidCallback onMarkPaid;

  /// Undo Mark paid.
  final VoidCallback onUndo;

  /// Open Edit amounts.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warn = theme.extension<SemanticColors>()?.warning;
    final p = card.position;
    final due = card.dueDay;
    final billed = card.billedMinor ?? 0;
    final days = due == null ? null : daysToDue(due, nowMs);
    final limit = card.limitMinor;
    final left = card.limitLeftMinor;
    final used = limit != null && limit > 0 && left != null
        ? ((limit - left) / limit).clamp(0.0, 1.0)
        : null;
    Widget row(String k, String v, {Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(k, style: theme.textTheme.bodyMedium)),
              Text(v, key: key, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
    return AppCard(
      key: Key('card_tile_${card.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${card.name} ••${card.last4}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (p.edited)
                Chip(
                  key: Key('card_edited_${card.id}'),
                  label: const Text('Edited'),
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                key: Key('card_edit_${card.id}'),
                tooltip: 'Edit amounts',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            ],
          ),
          if (billed > 0)
            row(
              p.estimated ? 'Billed (est.)' : 'Billed',
              '${p.estimated ? '~' : ''}${cardMoney(billed, masked: masked)}',
              key: Key('card_billed_${card.id}'),
            )
          else if ((card.outstandingMinor ?? 0) > 0)
            row(
              'Outstanding',
              cardMoney(card.outstandingMinor!, masked: masked),
              key: Key('card_outstanding_${card.id}'),
            ),
          if (card.minDueMinor != null && billed > 0)
            row('Min due', cardMoney(card.minDueMinor!, masked: masked)),
          if (due != null) row('Due date', cardDate(due)),
          if (card.unbilledMinor != null)
            row('Unbilled', cardMoney(card.unbilledMinor!, masked: masked)),
          if (left != null)
            row(
              'Limit left',
              cardMoney(left, masked: masked),
              key: Key('card_left_${card.id}'),
            ),
          if (used != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              key: Key('card_used_${card.id}'),
              value: used,
              color: used >= 0.8 ? theme.colorScheme.error : null,
            ),
          ],
          if (billed > 0 && days != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      card.paid ? 'Marked paid' : dueLabel(days),
                      key: Key('card_due_label_${card.id}'),
                      style: TextStyle(
                        color: card.paid
                            ? null
                            : days < 0
                                ? theme.colorScheme.error
                                : days <= 5
                                    ? warn
                                    : null,
                      ),
                    ),
                  ),
                  if (card.paid)
                    TextButton(
                      key: Key('card_undo_${card.id}'),
                      onPressed: onUndo,
                      child: const Text('Undo'),
                    )
                  else
                    FilledButton.tonal(
                      key: Key('card_mark_paid_${card.id}'),
                      onPressed: onMarkPaid,
                      child: const Text('Mark paid'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

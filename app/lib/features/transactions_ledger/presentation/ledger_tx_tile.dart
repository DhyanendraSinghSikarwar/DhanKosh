import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_category_style.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:parser_core/parser_core.dart' hide Money;

/// Signed amount text of [t] in the row's own currency; [whole] drops `.00`.
String txAmountText(LedgerTx t, {required bool masked, bool whole = false}) {
  final base = formatMoney(
    Money(t.amountMinor, currency: t.currency),
    masked: masked,
    showPaise: !whole || t.amountMinor % 100 != 0,
  );
  return switch (t.type) {
    TransactionType.credit => '+$base',
    TransactionType.debit || TransactionType.investment => '-$base',
    TransactionType.transfer => base,
  };
}

/// Small rounded Card / Account tag.
class SourceTag extends StatelessWidget {
  /// Creates the tag for [kind].
  const SourceTag(this.kind, {super.key});

  /// Account or card.
  final AccountKind kind;

  @override
  Widget build(BuildContext context) {
    final card = kind == AccountKind.card;
    final color = card ? AppIcons.violet : AppIcons.mint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        card ? 'Card' : 'Account',
        style: TextStyle(fontSize: 10, color: color, height: 1.2),
      ),
    );
  }
}

/// One ledger row: round category badge, merchant, `Category · Account`,
/// amount and a Card/Account tag; opens the detail (FR-08-02).
class LedgerTxTile extends StatelessWidget {
  /// Creates a tile.
  const LedgerTxTile({
    required this.tx,
    required this.masked,
    this.selecting = false,
    this.selected = false,
    this.onToggle,
    super.key,
  });

  /// The row.
  final LedgerTx tx;

  /// Hide-amounts setting.
  final bool masked;

  /// Multi-select mode: a tap toggles instead of opening (FR-08-08).
  final bool selecting;

  /// Whether the row is selected.
  final bool selected;

  /// Toggles selection; a long press starts it.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = theme.extension<SemanticColors>()!;
    final credit = tx.type == TransactionType.credit;
    final style = categoryStyle(tx.category);
    final last4 = tx.accountLast4;
    var amount = txAmountText(tx, masked: masked, whole: true);
    if (amount.startsWith('-')) amount = amount.substring(1);
    final bank = last4 != null ? '${tx.bankName} ••$last4' : tx.bankName;
    return InkWell(
      key: Key('tx-${tx.id}'),
      onLongPress: onToggle,
      onTap: selecting && onToggle != null
          ? onToggle
          : () => context.push('/transaction/${tx.id}'),
      child: Container(
        color: selected ? scheme.secondaryContainer : null,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
              ),
              child: selecting
                  ? Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: scheme.primary,
                    )
                  : Icon(style.icon, size: 18, color: style.color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    [
                      tx.category.label,
                      bank,
                      if (tx.needsReview) 'Needs review',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: credit ? sem.income : null,
                  ),
                ),
                const SizedBox(height: 2),
                SourceTag(tx.accountKind),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin separator between rows of one card.
class TxDivider extends StatelessWidget {
  /// Creates the divider.
  const TxDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(
              alpha: 0.5,
            ),
      );
}

/// [rows] separated by [TxDivider]s.
List<Widget> withDividers(Iterable<Widget> rows) {
  final out = <Widget>[];
  for (final r in rows) {
    if (out.isNotEmpty) out.add(const TxDivider());
    out.add(r);
  }
  return out;
}

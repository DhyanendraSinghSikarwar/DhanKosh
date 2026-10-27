import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/categorization/domain/brand_logos.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/widgets/brand_logo.dart';
import 'package:parser_core/parser_core.dart' hide Money;

/// Signed amount text of [t] in the row's own currency (paise only).
String txAmountText(LedgerTx t, {required bool masked}) {
  final base = formatMoney(
    Money(t.amountMinor, currency: t.currency),
    masked: masked,
  );
  return switch (t.type) {
    TransactionType.credit => '+$base',
    TransactionType.debit || TransactionType.investment => '-$base',
    TransactionType.transfer => base,
  };
}

/// One ledger row: merchant, category, bank, amount; opens the detail
/// (FR-08-02).
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
    final sem = theme.extension<SemanticColors>()!;
    final color = switch (tx.type) {
      TransactionType.credit => sem.income,
      TransactionType.debit || TransactionType.investment => sem.expense,
      TransactionType.transfer => theme.colorScheme.onSurfaceVariant,
    };
    final last4 = tx.accountLast4;
    return ListTile(
      key: Key('tx-${tx.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      selected: selected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      leading: selecting
          ? Icon(selected ? Icons.check_circle : Icons.circle_outlined)
          : BrandLogo(
              logoKey: BrandLogos.merchant(tx.merchant) ??
                  BrandLogos.bank(tx.bankName),
              label: tx.title,
              size: 36,
            ),
      onLongPress: onToggle,
      onTap: selecting && onToggle != null
          ? onToggle
          : () => context.push('/transaction/${tx.id}'),
      title: Text(tx.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          tx.category.label,
          if (last4 != null) '${tx.bankName} ••$last4' else tx.bankName,
          if (tx.accountKind == AccountKind.card) 'Card' else 'Account',
          if (tx.needsReview) 'Needs review',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        txAmountText(tx, masked: masked),
        style: theme.textTheme.titleSmall?.copyWith(color: color),
      ),
    );
  }
}

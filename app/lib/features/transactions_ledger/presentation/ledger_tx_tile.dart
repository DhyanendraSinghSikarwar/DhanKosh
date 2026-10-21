import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
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
  const LedgerTxTile({required this.tx, required this.masked, super.key});

  /// The row.
  final LedgerTx tx;

  /// Hide-amounts setting.
  final bool masked;

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
      onTap: () => context.push('/transaction/${tx.id}'),
      title: Text(tx.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          tx.category.label,
          if (last4 != null) '${tx.bankName} ••$last4' else tx.bankName,
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

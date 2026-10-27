import 'package:flutter/material.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_views.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Spends grouped by category with card and account together and a subtotal
/// split (FR-08-23, ADR-0011); a group expands to its rows.
class LedgerCategoryView extends StatelessWidget {
  /// Creates the view over [rows].
  const LedgerCategoryView({
    required this.rows,
    required this.masked,
    required this.rowBuilder,
    super.key,
  });

  /// Rows to group (period and filters already applied).
  final List<LedgerTx> rows;

  /// Hide-amounts setting.
  final bool masked;

  /// Builds a tile for one row.
  final Widget Function(LedgerTx) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String amt(int v) => formatAmount(v, masked: masked, paise: false);
    return Column(
      children: [
        for (final g in groupByCategory(rows))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                key: Key('category_${g.category.name}'),
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(g.category.label),
                subtitle: Text(
                  [
                    if (g.accountMinor != 0) 'Account ${amt(g.accountMinor)}',
                    if (g.cardMinor != 0) 'Card ${amt(g.cardMinor)}',
                  ].join(' · '),
                  key: Key('category_split_${g.category.name}'),
                ),
                trailing: Text(
                  amt(g.totalMinor),
                  style: theme.textTheme.titleSmall,
                ),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                children: [for (final t in g.rows) rowBuilder(t)],
              ),
            ),
          ),
      ],
    );
  }
}

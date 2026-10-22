import 'package:flutter/material.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_views.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Rows grouped by `merchant ?: bankName`, largest gross first; a group
/// expands to its rows (FR-08-04).
class LedgerMerchantView extends StatelessWidget {
  /// Creates the view over [rows].
  const LedgerMerchantView({
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
    return Column(
      children: [
        for (final g in groupByMerchant(rows))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                key: Key('merchant_${g.name}'),
                shape: const Border(),
                collapsedShape: const Border(),
                title:
                    Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${g.rows.length} transaction${g.rows.length == 1 ? '' : 's'}',
                ),
                trailing: Text(
                  formatAmount(g.grossMinor, masked: masked, paise: false),
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

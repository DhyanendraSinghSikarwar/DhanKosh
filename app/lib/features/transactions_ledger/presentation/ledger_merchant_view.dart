import 'package:flutter/material.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_views.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_tx_tile.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Rows grouped by `merchant ?: bankName`, largest gross first; a group
/// expands to its rows (FR-08-04).
class LedgerMerchantView extends StatefulWidget {
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
  State<LedgerMerchantView> createState() => _LedgerMerchantViewState();
}

class _LedgerMerchantViewState extends State<LedgerMerchantView> {
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final groups = groupByMerchant(widget.rows);
    return AppCard(
      key: const Key('merchant_card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: withDividers([
          for (final g in groups)
            Column(
              children: [
                InkWell(
                  key: Key('merchant_${g.name}'),
                  onTap: () => setState(() {
                    if (!_open.remove(g.name)) _open.add(g.name);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.surfaceContainerHighest,
                          ),
                          child: Text(
                            g.name.isEmpty ? '?' : g.name[0].toUpperCase(),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                '${g.rows.length} '
                                '${g.rows.length == 1 ? 'payment' : 'payments'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatAmount(
                            g.grossMinor,
                            masked: widget.masked,
                            paise: false,
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_open.contains(g.name))
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      children: withDividers(
                        [for (final t in g.rows) widget.rowBuilder(t)],
                      ),
                    ),
                  ),
              ],
            ),
        ]),
      ),
    );
  }
}

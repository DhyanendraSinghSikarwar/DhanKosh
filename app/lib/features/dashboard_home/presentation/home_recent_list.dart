import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:parser_core/parser_core.dart';

/// Latest transactions with "All" link (FR-17-12).
class HomeRecentList extends StatelessWidget {
  const HomeRecentList({required this.txs, required this.masked, super.key});

  final List<LedgerTx> txs;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<SemanticColors>();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  key: const Key('home_all_transactions'),
                  onPressed: () => context.go('/transactions'),
                  child: const Text('All'),
                ),
              ],
            ),
          ),
          if (txs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nothing yet'),
            ),
          for (final t in txs)
            ListTile(
              key: Key('home_tx_${t.id}'),
              title:
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(t.category.label),
              trailing: Text(
                '${t.type == TransactionType.credit ? '+' : '-'}'
                '${formatAmount(t.inrMinor ?? t.amountMinor, masked: masked)}',
                style: TextStyle(
                  color:
                      t.type == TransactionType.credit ? colors?.income : null,
                ),
              ),
              onTap: () => context.push('/transaction/${t.id}'),
            ),
        ],
      ),
    );
  }
}

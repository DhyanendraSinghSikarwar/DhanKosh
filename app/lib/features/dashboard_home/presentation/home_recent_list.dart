import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';
import 'package:parser_core/parser_core.dart';

/// Latest transactions with "All" link (FR-17-12).
class HomeRecentList extends StatelessWidget {
  const HomeRecentList({required this.txs, required this.masked, super.key});

  final List<LedgerTx> txs;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            'Recent',
            trailing: MoreLink(
              'All ›',
              key: const Key('home_all_transactions'),
              onTap: () => context.go('/transactions'),
            ),
          ),
          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Nothing yet', style: MockText.small(context)),
            ),
          for (final (n, t) in txs.indexed)
            InkWell(
              key: Key('home_tx_${t.id}'),
              onTap: () => context.push('/transaction/${t.id}'),
              child: IconAmountRow(
                icon: AppIcon(
                  t.type == TransactionType.credit
                      ? Icons.south_west
                      : Icons.north_east,
                  t.type == TransactionType.credit
                      ? AppIcons.mint
                      : AppIcons.red,
                ),
                title: t.title,
                subtitle: t.category.label,
                divider: n < txs.length - 1,
                amount: '${t.type == TransactionType.credit ? '+' : '-'}'
                    '${formatAmount(t.inrMinor ?? t.amountMinor, masked: masked, paise: false)}',
                amountSize: 15,
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hisaab/features/portfolio/domain/investment_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

/// Investment transactions: buys, redemptions and dividends (FR-16-25).
class InvestmentTxSection extends StatelessWidget {
  /// Creates the section.
  const InvestmentTxSection({
    required this.items,
    required this.money,
    super.key,
  });

  /// Newest first.
  final List<LedgerTx> items;

  /// Amount formatter (honours hide amounts).
  final String Function(int) money;

  static String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms + 19800000, isUtc: true);
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('investment-txs'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Investment transactions'),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('None yet', key: Key('investment-txs-empty')),
            ),
          for (final t in items.take(10))
            ListTile(
              key: Key('inv-tx-${t.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle:
                  Text('${investmentKind(t).label} · ${_date(t.timestamp)}'),
              trailing: Text(money(t.amountMinor)),
            ),
        ],
      ),
    );
  }
}

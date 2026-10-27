import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/transactions_ledger/domain/day_groups.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Income / Expenses / Net for the rows shown (FR-08-01, FR-20-18).
class LedgerSummaryStrip extends StatelessWidget {
  /// Creates the strip.
  const LedgerSummaryStrip({
    required this.summary,
    required this.count,
    required this.periodLabel,
    required this.masked,
    super.key,
  });

  /// Totals of the shown rows.
  final LedgerSummary summary;

  /// Rows shown.
  final int count;

  /// e.g. "This month".
  final String periodLabel;

  /// Hide-amounts setting.
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    Widget cell(String label, int minor, Color color, String key) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              Text(
                formatAmount(minor, masked: masked, paise: false),
                key: Key(key),
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
        );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              cell('Income', summary.incomeMinor, sem.income, 'sum_income'),
              cell('Expenses', summary.spentMinor, sem.expense, 'sum_spent'),
              cell(
                'Net',
                summary.netMinor,
                summary.netMinor < 0 ? sem.expense : sem.income,
                'sum_net',
              ),
            ],
          ),
          if (summary.cardMinor > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Card purchases '
              '${formatAmount(summary.cardMinor, masked: masked, paise: false)}'
              ' · not in Expenses',
              key: const Key('sum_card'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Expenses exclude card purchases, include card bill payments',
            key: const Key('sum_basis'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '$count transactions · $periodLabel',
            key: const Key('sum_caption'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

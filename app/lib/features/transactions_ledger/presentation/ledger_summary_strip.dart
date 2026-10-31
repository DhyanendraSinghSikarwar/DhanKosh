import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/transactions_ledger/domain/day_groups.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

/// Expenses / Income / Net card for the rows shown; the (i) opens the
/// cash-basis note (FR-08-01, FR-20-18).
class LedgerSummaryStrip extends StatefulWidget {
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
  State<LedgerSummaryStrip> createState() => _LedgerSummaryStripState();
}

class _LedgerSummaryStripState extends State<LedgerSummaryStrip> {
  bool _info = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    final summary = widget.summary;
    final big = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 19,
    );
    Widget cell(
      String label,
      int minor,
      Color? color,
      String key, {
      Widget? trailing,
    }) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 18,
                child: Row(
                  children: [
                    SectionLabel(label),
                    if (trailing != null) trailing,
                  ],
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatAmount(minor, masked: widget.masked, paise: false),
                  key: Key(key),
                  style: big?.copyWith(color: color),
                ),
              ),
            ],
          ),
        );
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(
                'Expenses',
                summary.spentMinor,
                null,
                'sum_spent',
                trailing: InkWell(
                  key: const Key('sum_info'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _info = !_info),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.info_outline,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              cell('Income', summary.incomeMinor, sem.income, 'sum_income'),
              const SizedBox(width: 8),
              cell(
                'Net',
                summary.netMinor,
                summary.netMinor < 0 ? sem.expense : sem.income,
                'sum_net',
              ),
            ],
          ),
          if (_info) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expenses exclude card purchases, include card bill '
                    'payments',
                    key: const Key('sum_basis'),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (summary.cardMinor > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Card purchases '
                      '${formatAmount(summary.cardMinor, masked: widget.masked, paise: false)}'
                      ' · not in Expenses',
                      key: const Key('sum_card'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${widget.count} transactions · ${widget.periodLabel}',
                    key: const Key('sum_caption'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

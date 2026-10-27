import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_providers.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_spent_chart.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Spent this month: headline, change versus last month, running line,
/// income / expenses / saved (FR-17-06).
class HomeSpentCard extends ConsumerWidget {
  /// Creates the card.
  const HomeSpentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<SemanticColors>();
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final month = ref.watch(homeMonthProvider);
    final totals = ref.watch(homeTotalsProvider).value;
    final rows = ref.watch(homeMonthTxsProvider).value;
    final now = DateTime.now();
    final isCurrent = month.isCurrent(now);
    final notifier = ref.read(homeMonthProvider.notifier);
    final spent = totals?.netSpentMinor ?? 0;
    final daysThis =
        DateUtils.getDaysInMonth(month.start.year, month.start.month);
    final prevStart = month.previous.start;
    final daysPrev = DateUtils.getDaysInMonth(prevStart.year, prevStart.month);
    final upTo = isCurrent ? now.day : daysThis;
    final prevSame =
        rows == null ? 0 : spentUpToDay(rows.prev, upTo.clamp(1, daysPrev));
    final change = SpendCalc.changePercent(spent, prevSame);
    final curSeries = rows == null
        ? const <int>[]
        : cumulativeSpend(rows.cur, daysInMonth: daysThis, upToDay: upTo);
    final prevSeries = rows == null
        ? const <int>[]
        : cumulativeSpend(rows.prev, daysInMonth: daysPrev);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('home_month_prev'),
                icon: const Icon(Icons.chevron_left),
                onPressed: notifier.previous,
              ),
              Expanded(
                child: Text(
                  month.label,
                  key: const Key('home_month_label'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('home_month_next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrent ? null : notifier.next,
              ),
            ],
          ),
          Text(isCurrent ? 'Spent this month' : 'Spent'),
          InkWell(
            key: const Key('home_spent_tap'),
            onTap: () => context.go('/analysis'),
            child: Text(
              formatAmount(spent, masked: masked),
              key: const Key('home_spent'),
              style: theme.textTheme.headlineMedium,
            ),
          ),
          if ((totals?.cardPurchasesMinor ?? 0) > 0)
            Text(
              'Card purchases '
              '${formatAmount(totals!.cardPurchasesMinor, masked: masked, paise: false)}'
              ' · paid via card bills',
              key: const Key('home_card_purchases'),
              style: theme.textTheme.bodySmall,
            ),
          if (change != null)
            Text(
              '${change > 0 ? '▲' : change < 0 ? '▼' : ''} '
              '${change.abs()}% vs last month',
              key: const Key('home_spent_change'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: change > 0 ? colors?.expense : colors?.income,
              ),
            ),
          if (curSeries.length > 1 || prevSeries.length > 1) ...[
            const SizedBox(height: 8),
            HomeSpentChart(current: curSeries, previous: prevSeries),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Income',
                  value: formatAmount(totals?.incomeMinor ?? 0, masked: masked),
                  color: colors?.income,
                  valueKey: const Key('home_income'),
                ),
              ),
              Expanded(
                child: _Tile(
                  label: 'Expenses',
                  value: formatAmount(totals?.outMinor ?? 0, masked: masked),
                  valueKey: const Key('home_expenses'),
                ),
              ),
              Expanded(
                child: _Tile(
                  label: 'Saved',
                  value: formatAmount(
                    (totals?.incomeMinor ?? 0) - (totals?.outMinor ?? 0),
                    masked: masked,
                  ),
                  valueKey: const Key('home_saved'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.valueKey,
    this.color,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          value,
          key: valueKey,
          style: theme.textTheme.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

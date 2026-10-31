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
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// Spent this month: headline, change versus last month, running line,
/// income / expenses / saved (FR-17-06).
class HomeSpentCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const HomeSpentCard({super.key});

  @override
  ConsumerState<HomeSpentCard> createState() => _HomeSpentCardState();
}

class _HomeSpentCardState extends ConsumerState<HomeSpentCard> {
  bool _info = false;

  @override
  Widget build(BuildContext context) {
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
    final prevLabel = prevSame > 0
        ? ' ${formatAmount(prevSame, masked: masked, paise: false)}'
        : '';
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            isCurrent ? 'Spent this month' : 'Spent',
            info: InfoDot(
              key: const Key('home_spent_info'),
              onTap: () => setState(() => _info = !_info),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Step(
                  key: const Key('home_month_prev'),
                  icon: Icons.chevron_left,
                  onTap: notifier.previous,
                ),
                Text(
                  month.label,
                  key: const Key('home_month_label'),
                  style: MockText.small(context),
                ),
                _Step(
                  key: const Key('home_month_next'),
                  icon: Icons.chevron_right,
                  onTap: isCurrent ? null : notifier.next,
                ),
              ],
            ),
          ),
          if (_info)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Money out of your accounts, including payments to credit '
                'cards. Card purchases are not counted again.',
                key: const Key('home_spent_note'),
                style: MockText.small(context),
              ),
            ),
          const SizedBox(height: 2),
          InkWell(
            key: const Key('home_spent_tap'),
            onTap: () => context.go('/analysis'),
            child: Text(
              formatAmount(spent, masked: masked, paise: false),
              key: const Key('home_spent'),
              style: MockText.big(context),
            ),
          ),
          if (change != null)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${change > 0 ? '▲' : change < 0 ? '▼' : ''} '
                        '${change.abs()}%',
                    style: TextStyle(
                      color: change > 0 ? colors?.expense : colors?.income,
                    ),
                  ),
                  TextSpan(text: ' vs last month$prevLabel'),
                ],
              ),
              key: const Key('home_spent_change'),
              style: MockText.small(context, color: muted),
            ),
          if ((totals?.cardPurchasesMinor ?? 0) > 0)
            Text(
              'Card purchases '
              '${formatAmount(totals!.cardPurchasesMinor, masked: masked, paise: false)}'
              ' · paid via card bills',
              key: const Key('home_card_purchases'),
              style: MockText.small(context),
            ),
          if (curSeries.length > 1 || prevSeries.length > 1) ...[
            const SizedBox(height: 8),
            HomeSpentChart(current: curSeries, previous: prevSeries),
          ],
          const SizedBox(height: 8),
          LegendRow([
            LegendItem(
              isCurrent ? 'This month' : month.label,
              theme.colorScheme.primary,
            ),
            LegendItem('Last month', muted),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Income',
                  value: formatAmount(
                    totals?.incomeMinor ?? 0,
                    masked: masked,
                    paise: false,
                  ),
                  color: colors?.income,
                  valueKey: const Key('home_income'),
                ),
              ),
              Expanded(
                child: _Tile(
                  label: 'Expenses',
                  value: formatAmount(
                    totals?.outMinor ?? 0,
                    masked: masked,
                    paise: false,
                  ),
                  valueKey: const Key('home_expenses'),
                ),
              ),
              Expanded(
                child: _Tile(
                  label: 'Saved',
                  value: formatAmount(
                    (totals?.incomeMinor ?? 0) - (totals?.outMinor ?? 0),
                    masked: masked,
                    paise: false,
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

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 16,
        child: Icon(
          icon,
          size: 20,
          color: onTap == null
              ? Theme.of(context).disabledColor
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MockText.small(context)),
        Text(
          value,
          key: valueKey,
          style: MockText.body(context, color: color)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/budget_providers.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/income_tracking/domain/cash_flow.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Income and cash flow: income vs spend, saved, savings rate (F-11,
/// FR-11-05, FR-11-06, FR-11-07, FR-11-09). Route `/income`.
class IncomeTrackingScreen extends ConsumerWidget {
  const IncomeTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final month = ref.watch(incomeMonthProvider);
    final notifier = ref.read(incomeMonthProvider.notifier);
    final flows = ref.watch(monthlyFlowsProvider(month)).value;
    final key =
        '${month.start.year}-${month.start.month.toString().padLeft(2, '0')}';
    final current = flows?.where((f) => f.yearMonth == key).firstOrNull;
    final flow = current?.flow ??
        const CashFlow(incomeMinor: 0, spentMinor: 0, investedMinor: 0);
    final rates = [
      for (final f in flows ?? const <MonthFlow>[])
        if (f.yearMonth != key && f.incomeMinor > 0) f.flow.ratePercent ?? 0,
    ];
    final rate = flow.ratePercent;
    final best = rate == null ? null : CashFlowMath.bestInMonths(rate, rates);
    final series = CashFlowMath.savingsRateSeries(flows ?? const []);
    final empty = flows != null &&
        flows.every((f) => f.incomeMinor == 0 && f.spentMinor == 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('income_month_prev'),
                icon: const Icon(Icons.chevron_left),
                onPressed: notifier.previous,
              ),
              Expanded(
                child: Text(
                  month.label,
                  key: const Key('income_month_label'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('income_month_next'),
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    month.isCurrent(DateTime.now()) ? null : notifier.next,
              ),
            ],
          ),
          if (flows == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Loading…')),
            )
          else if (empty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.trending_up,
                title: 'No income yet',
                hint: 'Credits from your bank show up here.',
              ),
            )
          else ...[
            AppCard(
              key: const Key('income_cashflow'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      for (final (label, v, k) in [
                        ('Income', flow.incomeMinor, 'income_total'),
                        ('Spent', flow.spentMinor, 'income_spent'),
                        ('Invested', flow.investedMinor, 'income_invested'),
                        ('Saved', flow.savedMinor, 'income_saved'),
                      ])
                        _Stat(label, v, k, masked: masked),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    rate == null
                        ? 'No income this month'
                        : 'Savings rate $rate%',
                    key: const Key('income_rate'),
                  ),
                  if (best != null)
                    Text(
                      'Best in $best months',
                      key: const Key('income_best'),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              key: const Key('income_chart_card'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Income vs spent', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SizedBox(height: 160, child: _FlowChart(flows: flows)),
                ],
              ),
            ),
            if (series.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppCard(
                key: const Key('income_rate_series'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Savings rate', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final p in series.reversed.take(6))
                      Row(
                        children: [
                          Expanded(child: Text(p.yearMonth)),
                          Text('${p.percent.round()}%'),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.minor, this.keyName, {required this.masked});

  final String label;
  final int minor;
  final bool masked;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          formatAmount(minor, masked: masked, paise: false),
          key: Key(keyName),
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _FlowChart extends StatelessWidget {
  const _FlowChart({required this.flows});

  final List<MonthFlow> flows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SemanticColors>();
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        barTouchData: const BarTouchData(enabled: false),
        barGroups: [
          for (var i = 0; i < flows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: flows[i].incomeMinor / 100,
                  color: colors?.income,
                  width: 6,
                ),
                BarChartRodData(
                  toY: flows[i].spentMinor / 100,
                  color: colors?.expense,
                  width: 6,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

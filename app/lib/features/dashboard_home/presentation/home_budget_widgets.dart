import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/budget_providers.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_providers.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_spent_chart.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_math.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// Home budgets: up to three rings, most used first (FR-10-14).
class HomeBudgetsCard extends ConsumerWidget {
  const HomeBudgetsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final uses =
        ref.watch(budgetUsesProvider(MonthRange.of(DateTime.now()))).value;
    if (uses == null) return const SizedBox.shrink();
    return AppCard(
      key: const Key('home_budgets'),
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/budgets'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            'Budgets',
            trailing: uses.isEmpty ? const Text('Set budgets') : null,
          ),
          const SizedBox(height: 10),
          if (uses.isEmpty)
            Text(
              'Set monthly limits for the categories you watch.',
              style: MockText.small(context),
            )
          else
            Row(
              children: [
                for (final u in uses.take(3))
                  Expanded(
                    child: Column(
                      key: Key('home_ring_${u.category.name}'),
                      children: [
                        SizedBox(
                          width: 62,
                          height: 62,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: u.fraction.clamp(0, 1).toDouble(),
                                  strokeWidth: 6,
                                  strokeCap: StrokeCap.round,
                                  color: _ringColor(
                                    context,
                                    BudgetMath.ringBand(
                                      u.spentMinor,
                                      u.limitMinor,
                                    ),
                                  ),
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                              ),
                              Text(
                                '${(u.fraction * 100).toInt()}%',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          u.category.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MockText.small(
                            context,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          masked
                              ? formatAmount(u.spentMinor, masked: true)
                              : '₹${HomeSpentChart.compact(u.spentMinor / 100)}',
                          key: Key('home_ring_spent_${u.category.name}'),
                          style: MockText.small(context),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Home cash flow: income, spent, invested, saved and rate (FR-11-06).
class HomeCashFlowCard extends ConsumerStatefulWidget {
  const HomeCashFlowCard({super.key});

  @override
  ConsumerState<HomeCashFlowCard> createState() => _HomeCashFlowCardState();
}

class _HomeCashFlowCardState extends ConsumerState<HomeCashFlowCard> {
  bool _info = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final month = ref.watch(homeMonthProvider);
    final flows = ref.watch(monthlyFlowsProvider(month)).value;
    if (flows == null) return const SizedBox.shrink();
    final key =
        '${month.start.year}-${month.start.month.toString().padLeft(2, '0')}';
    final m = flows.where((f) => f.yearMonth == key).firstOrNull;
    if (m == null) return const SizedBox.shrink();
    final f = m.flow;
    String amt(int v) => formatAmount(v, masked: masked, paise: false);
    final colors = theme.extension<SemanticColors>();
    final bar = splitBar(
      incomeMinor: f.incomeMinor,
      spentMinor: f.spentMinor,
      investedMinor: f.investedMinor,
    );
    const violet = AppIcons.violet;
    return AppCard(
      key: const Key('home_cashflow'),
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/income'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            'Cash flow',
            info: InfoDot(
              key: const Key('home_cashflow_info'),
              onTap: () => setState(() => _info = !_info),
            ),
          ),
          if (_info)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Where this month’s income went.',
                style: MockText.small(context),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amt(f.incomeMinor),
                      key: const Key('home_cashflow_line'),
                      style: MockText.mid(context, color: colors?.income),
                    ),
                    Text('Income', style: MockText.small(context)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amt(f.savedMinor),
                    key: const Key('home_cashflow_saved'),
                    style: MockText.mid(context),
                  ),
                  Text(
                    f.ratePercent == null
                        ? 'Saved'
                        : 'Saved · ${f.ratePercent}%',
                    style: MockText.small(context),
                  ),
                ],
              ),
            ],
          ),
          if (f.incomeMinor > 0) ...[
            const SizedBox(height: 10),
            _SplitBar(bar: bar),
            const SizedBox(height: 8),
            const LegendRow([
              LegendItem('Spent', AppIcons.mint),
              LegendItem('Invested', AppIcons.amber),
              LegendItem('Saved', violet),
            ]),
          ],
        ],
      ),
    );
  }
}

Color _ringColor(BuildContext context, BudgetBand band) {
  final colors = Theme.of(context).extension<SemanticColors>();
  return switch (band) {
    BudgetBand.red => colors?.expense ?? Colors.red,
    BudgetBand.amber => colors?.warning ?? Colors.orange,
    BudgetBand.normal => colors?.income ?? Colors.green,
  };
}

/// Spent / invested / saved as shares of income (FR-17-08, B12).
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.bar});

  final ({int spent, int invested, int saved}) bar;

  @override
  Widget build(BuildContext context) {
    Widget seg(int flex, Color c) => flex == 0
        ? const SizedBox.shrink()
        : Expanded(flex: flex, child: ColoredBox(color: c));
    return ClipRRect(
      key: const Key('home_split_bar'),
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 9,
        child: Row(
          children: [
            seg(bar.spent, AppIcons.mint),
            seg(bar.invested, AppIcons.amber),
            seg(bar.saved, AppIcons.violet),
          ],
        ),
      ),
    );
  }
}

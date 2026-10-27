import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/budget_providers.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_providers.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_math.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        key: const Key('home_budgets'),
        onTap: () => context.push('/budgets'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Budgets', style: theme.textTheme.titleMedium),
                ),
                Text(uses.isEmpty ? 'Set budgets' : 'Manage'),
              ],
            ),
            const SizedBox(height: 8),
            if (uses.isEmpty)
              const Text('Set monthly limits for the categories you watch.')
            else
              Row(
                children: [
                  for (final u in uses.take(3))
                    Expanded(
                      child: Column(
                        key: Key('home_ring_${u.category.name}'),
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: u.fraction.clamp(0, 1).toDouble(),
                                    strokeWidth: 6,
                                    color: _ringColor(
                                      context,
                                      BudgetMath.ringBand(
                                        u.spentMinor,
                                        u.limitMinor,
                                      ),
                                    ),
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                                Text('${(u.fraction * 100).toInt()}%'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            u.category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            formatAmount(
                              u.spentMinor,
                              masked: masked,
                              paise: false,
                            ),
                            key: Key('home_ring_spent_${u.category.name}'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Home cash flow: income, spent, invested, saved and rate (FR-11-06).
class HomeCashFlowCard extends ConsumerWidget {
  const HomeCashFlowCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        key: const Key('home_cashflow'),
        onTap: () => context.push('/income'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cash flow', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Income ${amt(f.incomeMinor)} · Spent ${amt(f.spentMinor)}'
              ' · Invested ${amt(f.investedMinor)}',
              key: const Key('home_cashflow_line'),
            ),
            Text(
              f.ratePercent == null
                  ? 'Saved ${amt(f.savedMinor)}'
                  : 'Saved ${amt(f.savedMinor)} · ${f.ratePercent}%',
              key: const Key('home_cashflow_saved'),
            ),
            if (f.incomeMinor > 0) ...[
              const SizedBox(height: 8),
              _SplitBar(
                bar: splitBar(
                  incomeMinor: f.incomeMinor,
                  spentMinor: f.spentMinor,
                  investedMinor: f.investedMinor,
                ),
              ),
            ],
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<SemanticColors>();
    Widget seg(int flex, Color c) => flex == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: flex,
            child: Container(height: 10, color: c),
          );
    return ClipRRect(
      key: const Key('home_split_bar'),
      borderRadius: BorderRadius.circular(5),
      child: Row(
        children: [
          seg(bar.spent, colors?.expense ?? Colors.red),
          seg(bar.invested, scheme.primary),
          seg(bar.saved, colors?.income ?? Colors.green),
        ],
      ),
    );
  }
}

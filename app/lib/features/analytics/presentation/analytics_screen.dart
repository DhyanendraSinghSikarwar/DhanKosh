import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/app/di/layout_providers.dart';
import 'package:hisaab/features/analytics/domain/analytics_view.dart';
import 'package:hisaab/features/analytics/domain/chart_data.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/analytics/presentation/analytics_cards.dart';
import 'package:hisaab/features/analytics/presentation/analytics_chart_cards.dart';
import 'package:hisaab/features/analytics/presentation/analytics_extra_cards.dart';
import 'package:hisaab/features/analytics/presentation/analytics_filter_bar.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

enum _View { spending, cash, forecast, compare }

/// Analysis tab: Spending, Cash flow, Forecast, Compare (F-18, FR-18-01).
class AnalyticsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _View _view = _View.spending;
  ChartSelection _sel = ChartSelection.none;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(analyticsViewProvider);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final v = async.value ?? AnalyticsView.empty;
    String money(int m) => formatAmount(m, masked: masked, paise: false);
    final d = v.data;
    final sections = ref.watch(visibleSectionsProvider(ScreenIds.analytics));
    final cash = SpendCalc.totals(v.txs, context: v.year);
    final parts = <String, Widget>{
      'categories': CategoryDonutCard(
        data: d,
        txs: v.txs,
        selection: _sel,
        onSelect: (s) => setState(() => _sel = s),
        money: money,
        onOpenCategory: (c) => context.push('/category/${c.name}'),
      ),
      'monthly': MonthlyTrendCard(
        months: LedgerMath.monthly(
          ChartData.select(v.year, _sel),
          [for (final m in d.monthly) m.month],
        ),
        money: money,
      ),
      'when': HeatmapCard(
        heat: _sel.category == null
            ? v.heat
            : LedgerMath.heat(
                ChartData.select(v.txs, _sel, withHeat: false),
              ),
        selection: _sel,
        onSelect: (s) => setState(() => _sel = s),
        money: money,
      ),
      'merchants': TopMerchantsCard(
        merchants: _sel.isEmpty
            ? v.merchants
            : LedgerMath.topMerchants(
                ChartData.select(v.txs, _sel),
              ),
        money: money,
      ),
      'budgets': BudgetsCard(data: d, money: money),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AnalyticsFilterBar(),
          const SizedBox(height: 8),
          SegmentedButton<_View>(
            key: const Key('analytics-view'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _View.spending, label: Text('Spend')),
              ButtonSegment(value: _View.cash, label: Text('Cash')),
              ButtonSegment(value: _View.forecast, label: Text('Forecast')),
              ButtonSegment(value: _View.compare, label: Text('Compare')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 16),
          if (!d.loaded)
            const SizedBox(
              height: 300,
              child: EmptyState(
                key: Key('analytics-empty'),
                icon: Icons.insights_outlined,
                title: 'Loading',
              ),
            )
          else if (v.txs.isEmpty && d.monthly.every((m) => m.spent == 0))
            const SizedBox(
              height: 300,
              child: EmptyState(
                key: Key('analytics-empty'),
                icon: Icons.insights_outlined,
                title: 'No spending yet',
                hint: 'Transactions show up here.',
              ),
            )
          else ...[
            InsightsCard(insights: v.insights),
            ...switch (_view) {
              _View.spending => [
                  KpiRow(data: d, money: money, spent: cash.spentMinor),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Expenses exclude card purchases and include card bill '
                      'payments. Card purchases: '
                      '${money(cash.cardPurchasesMinor)}',
                      key: const Key('analytics-basis-note'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  ...[
                    for (final id in sections)
                      if (parts[id] != null) parts[id]!,
                  ],
                  SubscriptionsCard(lines: v.subscriptions, money: money),
                  CardUtilisationCard(cards: v.cards, money: money),
                ],
              _View.cash => [
                  IncomeFlowCard(data: d, money: money),
                  IncomeSourcesCard(sources: v.incomeSources, money: money),
                  SavingsRateCard(data: d),
                  CashProjectionCard(data: d, money: money),
                ],
              _View.forecast => [ForecastCard(data: d, money: money)],
              _View.compare => [CompareCard(data: d, money: money)],
            },
          ],
        ],
      ),
    );
  }
}

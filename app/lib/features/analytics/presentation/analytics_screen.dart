import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/features/analytics/domain/analytics_view.dart';
import 'package:hisaab/features/analytics/presentation/analytics_cards.dart';
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

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(analyticsPeriodChoiceProvider);
    final async = ref.watch(analyticsViewProvider);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final v = async.value ?? AnalyticsView.empty;
    String money(int m) => formatAmount(m, masked: masked, paise: false);
    final d = v.data;
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<AnalyticsPeriod>(
            key: const Key('analytics-period'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: AnalyticsPeriod.thisMonth,
                label: Text('This month'),
              ),
              ButtonSegment(
                value: AnalyticsPeriod.lastMonth,
                label: Text('Last month'),
              ),
            ],
            selected: {period},
            onSelectionChanged: (s) => ref
                .read(analyticsPeriodChoiceProvider.notifier)
                .select(s.first),
          ),
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
                  KpiRow(data: d, money: money),
                  CategoryDonutCard(data: d, money: money),
                  MonthlyTrendCard(data: d, money: money),
                  HeatmapCard(heat: v.heat),
                  TopMerchantsCard(merchants: v.merchants, money: money),
                  BudgetsCard(data: d, money: money),
                ],
              _View.cash => [
                  IncomeFlowCard(data: d, money: money),
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

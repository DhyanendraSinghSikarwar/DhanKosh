import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/app/di/layout_providers.dart';
import 'package:hisaab/app/scope_bar.dart' show TabTitle;
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

enum _Tab {
  spend('Spend'),
  trends('Trends'),
  cash('Cash flow'),
  forecast('Forecast');

  const _Tab(this.label);
  final String label;
}

/// Layout-store sections that live in the Spend sub-tab; the rest of the
/// section ids belong to Trends.
const _spendSections = {'categories', 'merchants', 'budgets'};

class _TabStrip extends SliverPersistentHeaderDelegate {
  _TabStrip({required this.selected, required this.onSelect});
  final _Tab selected;
  final ValueChanged<_Tab> onSelect;

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SegmentedButton<_Tab>(
          key: const Key('analytics-view'),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final t in _Tab.values)
              ButtonSegment(value: t, label: Text(t.label)),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onSelect(s.first),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabStrip old) => old.selected != selected;
}

/// Analysis tab: Spend, Trends, Cash flow, Forecast sub-tabs (F-18, FR-18-01).
class AnalyticsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _Tab _tab = _Tab.spend;
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
    List<Widget> section(bool Function(String) inTab) => [
          for (final id in sections)
            if (inTab(id) && parts[id] != null) parts[id]!,
        ];
    final Widget content;
    if (!d.loaded) {
      content = const SizedBox(
        height: 300,
        child: EmptyState(
          key: Key('analytics-empty'),
          icon: Icons.insights_outlined,
          title: 'Loading',
        ),
      );
    } else if (v.txs.isEmpty && d.monthly.every((m) => m.spent == 0)) {
      content = const SizedBox(
        height: 300,
        child: EmptyState(
          key: Key('analytics-empty'),
          icon: Icons.insights_outlined,
          title: 'No spending yet',
          hint: 'Transactions show up here.',
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (_tab) {
          _Tab.spend => [
              InsightsCard(insights: v.insights),
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
              ...section(_spendSections.contains),
            ],
          _Tab.trends => [
              ...section((id) => !_spendSections.contains(id)),
              CompareCard(data: d, money: money),
              SubscriptionsCard(lines: v.subscriptions, money: money),
              CardUtilisationCard(cards: v.cards, money: money),
            ],
          _Tab.cash => [
              IncomeFlowCard(data: d, money: money),
              IncomeSourcesCard(sources: v.incomeSources, money: money),
              SavingsRateCard(data: d),
            ],
          _Tab.forecast => [
              ForecastCard(data: d, money: money),
              CashProjectionCard(data: d, money: money),
            ],
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const TabTitle('Analysis')),
      body: CustomScrollView(
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: AnalyticsFilterBar()),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabStrip(
              selected: _tab,
              onSelect: (t) => setState(() => _tab = t),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverToBoxAdapter(child: content),
          ),
        ],
      ),
    );
  }
}

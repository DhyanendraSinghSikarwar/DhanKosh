import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/app/di/layout_providers.dart';
import 'package:hisaab/app/scope_bar.dart' show BookTag;
import 'package:hisaab/features/analytics/domain/analytics_view.dart';
import 'package:hisaab/features/analytics/domain/chart_data.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/analytics/presentation/analytics_cards.dart';
import 'package:hisaab/features/analytics/presentation/analytics_chart_cards.dart';
import 'package:hisaab/features/analytics/presentation/analytics_extra_cards.dart';
import 'package:hisaab/features/analytics/presentation/analytics_filter_bar.dart';
import 'package:hisaab/features/analytics/presentation/analytics_spend_cards.dart';
import 'package:hisaab/features/analytics/presentation/analytics_tab_strip.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Layout-store sections that live in the Spend sub-tab; the rest of the
/// section ids belong to Trends.
const _spendSections = {'categories', 'merchants', 'budgets'};

/// Analysis tab: Spend, Trends, Cash flow, Forecast sub-tabs (F-18, FR-18-01).
class AnalyticsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _tab = 0;
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
    final from = v.rangeFrom;
    final to = v.rangeTo;
    final today = dayOf(DateTime.now().millisecondsSinceEpoch);
    final parts = <String, Widget>{
      'categories': CategoryDonutCard(
        data: d,
        txs: v.txs,
        selection: _sel,
        onSelect: (s) => setState(() => _sel = s),
        money: money,
        masked: masked,
        onOpenCategory: (c) => context.push('/category/${c.name}'),
      ),
      'monthly': MonthlyTrendCard(
        months: LedgerMath.monthly(
          ChartData.select(v.year, _sel),
          [for (final m in d.monthly) m.month],
        ),
        money: money,
        masked: masked,
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
    // Trends: the compare card follows the 12-month bars (mock order).
    List<Widget> trends() {
      final compare = CompareCard(data: d, money: money);
      final out = <Widget>[];
      var placed = false;
      for (final id in sections) {
        if (_spendSections.contains(id) || parts[id] == null) continue;
        out.add(parts[id]!);
        if (id == 'monthly') {
          out.add(compare);
          placed = true;
        }
      }
      if (!placed) out.insert(0, compare);
      return out;
    }

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
          0 => [
              TotalSpentCard(
                spent: cash.spentMinor,
                txCount: v.txs.where(LedgerMath.isSpend).length,
                perDay: d.perDay,
                money: money,
                tip: 'Expenses exclude card purchases and include card bill '
                    'payments. Card purchases: '
                    '${money(cash.cardPurchasesMinor)}. Same total as Home.',
                forecast: d.forecast?.likely,
                forecastDay: to,
              ),
              if (from != null && to != null)
                DailySpendCard(
                  txs: ChartData.select(v.txs, _sel, withHeat: false),
                  from: from,
                  to: to,
                  upto: today,
                  masked: masked,
                ),
              ...section(_spendSections.contains),
              KpiRow(data: d, money: money, spent: cash.spentMinor),
              InsightsCard(insights: v.insights),
            ],
          1 => [
              ...trends(),
              SubscriptionsCard(lines: v.subscriptions, money: money),
              CardUtilisationCard(cards: v.cards, money: money),
            ],
          2 => [
              IncomeFlowCard(data: d, money: money, masked: masked),
              IncomeVsSpendCard(months: d.monthly, masked: masked),
              SavingsRateCard(data: d),
              IncomeSourcesCard(sources: v.incomeSources, money: money),
            ],
          _ => [
              ForecastCard(data: d, money: money, masked: masked),
              CashProjectionCard(data: d, money: money, masked: masked),
            ],
        },
      );
    }
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Analysis',
                        key: const Key('analytics-title'),
                        overflow: TextOverflow.ellipsis,
                        style: t.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const BookTag(),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: AnalyticsTabStrip(
                labels: const ['Spend', 'Trends', 'Cash flow', 'Forecast'],
                selected: _tab,
                onSelect: (i) => setState(() => _tab = i),
                background: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(
                child: AnalyticsFilterBar(
                  selection: _sel,
                  onSelect: (s) => setState(() => _sel = s),
                  categories: [for (final e in d.categories) e.$1],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverToBoxAdapter(child: content),
            ),
          ],
        ),
      ),
    );
  }
}

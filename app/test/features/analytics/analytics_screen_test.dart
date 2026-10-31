import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/app/di/layout_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/analytics_view.dart';
import 'package:hisaab/features/analytics/domain/chart_data.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/analytics/presentation/analytics_screen.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/fake_settings.dart';
import '../../support/ui_harness.dart';

var _n = 0;
LedgerTx _tx(
  DateTime day,
  int rupees,
  Category c, {
  String? merchant,
  TransactionType type = TransactionType.debit,
}) {
  _n++;
  return LedgerTx(
    id: _n,
    amountMinor: rupees * 100,
    currency: 'INR',
    type: type,
    bankName: 'Test Bank',
    accountKind: AccountKind.account,
    channel: Channel.other,
    timestamp: epochMsOf(day, hour: 13),
    hasExplicitTime: true,
    category: c,
    transactionHash: 'h$_n',
    confidence: 1,
    needsReview: false,
    createdAt: 0,
    merchant: merchant,
  );
}

AnalyticsView _view(DateTime month, List<LedgerTx> all) {
  final to = DateTime.utc(month.year, month.month + 1, 0);
  final prev = addMonths(month, -1);
  List<LedgerTx> within(DateTime a, DateTime b) => all.where((t) {
        final x = dayOf(t.timestamp);
        return !x.isBefore(a) && !x.isAfter(b);
      }).toList();
  final txs = within(month, to);
  final slice = AnalyticsSlice(
    txs: txs,
    previous: within(prev, DateTime.utc(prev.year, prev.month + 1, 0)),
    year: all,
    months: [for (var i = 11; i >= 0; i--) addMonths(month, -i)],
    from: month,
    to: to,
    kind: AnalyticsPeriodKind.lastMonth,
    month: month,
    previousFrom: prev,
    previousTo: DateTime.utc(prev.year, prev.month + 1, 0),
  );
  final today = DateTime.utc(2026, 10, 21);
  return AnalyticsView(
    data: AnalyticsMath.build(
      slice: slice,
      plan: const PlanSnapshot(),
      budgets: const [],
      alertPercent: 90,
      today: today,
    ),
    txs: txs,
    insights: AnalyticsMath.insights(txs, const [], today),
    heat: LedgerMath.heat(txs),
    merchants: LedgerMath.topMerchants(txs),
    year: all,
  );
}

void main() {
  final rows = [
    _tx(
      DateTime.utc(2026, 9),
      80000,
      Category.salary,
      type: TransactionType.credit,
    ),
    _tx(
      DateTime.utc(2026, 9, 5),
      12000,
      Category.groceries,
      merchant: 'Fresh Mart',
    ),
    _tx(DateTime.utc(2026, 9, 9), 3000, Category.food, merchant: 'Cafe One'),
    _tx(DateTime.utc(2026, 8, 9), 5000, Category.food, merchant: 'Cafe One'),
  ];

  Future<void> pump(
    WidgetTester t, {
    List<LedgerTx> data = const [],
    bool dark = false,
  }) async {
    await t.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          hideAmountsProvider.overrideWith((ref) => Stream.value(false)),
          settingsRepositoryProvider.overrideWithValue(FakeSettings()),
          analyticsAccountsProvider.overrideWith((ref) => Stream.value([])),
          visibleSectionsProvider.overrideWith(
            (ref, id) => SectionLayout.visibleIds(SectionLayout.defaults(id)),
          ),
          analyticsViewProvider.overrideWith((ref) {
            final p = ref.watch(analyticsPeriodChoiceProvider);
            return Stream.value(
              _view(
                p == AnalyticsPeriod.thisMonth
                    ? DateTime.utc(2026, 10)
                    : DateTime.utc(2026, 9),
                data,
              ),
            );
          }),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: const AnalyticsScreen(),
        ),
      ),
    );
    await settle(t);
  }

  Future<void> tab(WidgetTester t, String label) async {
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('analytics-view')),
        matching: find.text(label),
      ),
    );
    await settle(t);
  }

  testWidgets('empty state (FR-18-01)', (t) async {
    await pump(t);
    expect(find.byKey(const Key('analytics-empty')), findsOneWidget);
    await teardownApp(t);
  });

  for (final dark in [false, true]) {
    testWidgets('populated ${dark ? 'dark' : 'light'} (FR-18-03..07)',
        (t) async {
      await pump(t, data: rows, dark: dark);
      await t.tap(find.text('Last month'));
      await settle(t);
      expect(find.byKey(const Key('analytics-donut')), findsOneWidget);
      expect(find.text('Fresh Mart (1)'), findsOneWidget);
      expect(find.text('₹15,000'), findsWidgets);
      await tab(t, 'Trends');
      expect(find.byKey(const Key('analytics-trend')), findsOneWidget);
      expect(find.byKey(const Key('analytics-heat')), findsOneWidget);
      await teardownApp(t);
    });
  }

  testWidgets('sub-tabs show their own cards (FR-18-01, FR-18-16)', (t) async {
    await pump(t, data: rows);
    await t.tap(find.text('Last month'));
    await settle(t);
    // Spend (default).
    expect(find.byKey(const Key('analytics-donut')), findsOneWidget);
    expect(find.byKey(const Key('analytics-trend')), findsNothing);
    expect(find.byKey(const Key('analytics-flow')), findsNothing);
    await tab(t, 'Trends');
    expect(find.byKey(const Key('analytics-trend')), findsOneWidget);
    expect(find.byKey(const Key('analytics-heat')), findsOneWidget);
    expect(find.byKey(const Key('analytics-compare')), findsOneWidget);
    expect(find.byKey(const Key('analytics-donut')), findsNothing);
    await tab(t, 'Cash flow');
    expect(find.byKey(const Key('analytics-flow')), findsOneWidget);
    expect(find.byKey(const Key('analytics-compare')), findsNothing);
    await tab(t, 'Forecast');
    expect(find.text('Forecast is for the current month.'), findsOneWidget);
    expect(find.byKey(const Key('analytics-fan')), findsNothing);
    // Filter bar stays above the tabs.
    expect(find.byKey(const Key('analytics-period')), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('book tag beside title (FR-20-23)', (t) async {
    await pump(t, data: rows);
    expect(find.byKey(const Key('book_tag')), findsOneWidget);
    expect(find.text('All books'), findsOneWidget);
    expect(find.byKey(const Key('book_business')), findsNothing);
    await teardownApp(t);
  });

  testWidgets('donut selection cross-filters and drills (FR-18-29)', (t) async {
    await pump(t, data: rows);
    await t.tap(find.text('Last month'));
    await settle(t);
    expect(find.text('Fresh Mart (1)'), findsOneWidget);
    expect(find.text('Cafe One (1)'), findsOneWidget);
    await t.tap(find.byKey(const Key('donut-row-1')));
    await settle(t);
    expect(find.byKey(const Key('donut-back')), findsOneWidget);
    expect(find.text('Cafe One (1)'), findsOneWidget);
    expect(find.text('Fresh Mart (1)'), findsNothing);
    await t.tap(find.byKey(const Key('donut-back')));
    await settle(t);
    expect(find.text('Fresh Mart (1)'), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('heat cell tap reads and filters (FR-18-29)', (t) async {
    await pump(t, data: rows);
    await t.tap(find.text('Last month'));
    await settle(t);
    await tab(t, 'Trends');
    final cell = ChartData.heatCell(rows[1])!;
    final key = Key('heat-${cell.$1}-${cell.$2}');
    await t.ensureVisible(find.byKey(key));
    await t.tap(find.byKey(key));
    await settle(t);
    expect(find.byKey(const Key('heat-readout')), findsOneWidget);
    await t.tap(find.byKey(key));
    await settle(t);
    expect(find.byKey(const Key('heat-readout')), findsNothing);
    await teardownApp(t);
  });

  testWidgets('basis note shows card purchases (ADR-0011)', (t) async {
    await pump(t, data: rows);
    await t.tap(find.text('Last month'));
    await settle(t);
    expect(find.byKey(const Key('analytics-basis-note')), findsOneWidget);
    expect(
      find.textContaining('Expenses exclude card purchases'),
      findsOneWidget,
    );
    await teardownApp(t);
  });
}

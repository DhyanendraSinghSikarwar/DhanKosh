import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/net_worth_estimate_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/portfolio/data/net_worth_repository_impl.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_estimate.dart';
import 'package:hisaab/features/portfolio/presentation/compact_money.dart';
import 'package:hisaab/features/portfolio/presentation/net_worth_chart.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

void main() {
  late TestEnv env;
  late HoldingRepositoryImpl holdings;
  setUp(() {
    env = TestEnv();
    holdings = HoldingRepositoryImpl(env.db);
  });
  tearDown(() => env.close());

  Future<void> pump(
    WidgetTester t, {
    bool dark = false,
    List<EstimatedPoint> estimate = const [],
  }) async {
    await t.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(env.accounts),
          transactionRepositoryProvider.overrideWithValue(env.txs),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          holdingRepositoryProvider.overrideWithValue(holdings),
          netWorthEstimateProvider.overrideWith((ref) async => estimate),
          netWorthRepositoryProvider
              .overrideWithValue(NetWorthRepositoryImpl(env.db)),
          netWorthProvider.overrideWith(
            (ref) => ref.watch(holdingsProvider.future).asStream().map(
              (h) {
                final v = h.fold<int>(0, (a, x) => a + (x.valueMinor ?? 0));
                return NetWorth(
                  assetsMinor: v,
                  liabilitiesMinor: 0,
                  parts: const [],
                  cards: const [],
                );
              },
            ),
          ),
          maturitiesProvider.overrideWith((ref) => Stream.value([])),
          loansStateProvider.overrideWith(
            (ref) async => const LoansState(loans: [], dismissed: {}),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: const PortfolioScreen(),
        ),
      ),
    );
    await settle(t);
  }

  Future<void> seed(WidgetTester t, {bool hide = false}) =>
      t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, hide);
        await holdings.addManual(
          kind: HoldingKind.mutualFund,
          name: 'Demo Equity Fund',
          valueMinor: 12000000,
          investedMinor: 10000000,
          at: env.clock,
        );
      });

  // FR-16-05: the line is drawn from the estimate, never blank with data.
  testWidgets('net worth chart uses the estimate and range pills', (t) async {
    await t.runAsync(() => env.settings.write(SettingKeys.hideAmounts, false));
    final day = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    await pump(
      t,
      estimate: [
        for (var i = 5; i >= 0; i--)
          EstimatedPoint(
            WorthPoint(day - i * 30, 1000000 + (5 - i) * 100000, 0),
            estimated: true,
          ),
      ],
    );
    expect(find.byType(NetWorthChart), findsOneWidget);
    expect(find.text('History builds up day by day'), findsNothing);
    expect(find.byKey(const Key('nw-summary')), findsOneWidget);
    expect(find.text('this year'), findsNothing);
    await t.tap(find.byKey(const Key('range-6M')));
    await t.pump();
    expect(find.textContaining('in 6 months'), findsOneWidget);
    await teardownApp(t);
  });

  test('compactMoney', () {
    expect(compactMoney(196000000), '19.6L');
    expect(compactMoney(1960000), '19.6K');
    expect(compactMoney(1840000000), '1.8Cr');
    expect(compactMoney(5000000), '50K');
    expect(compactMoney(-250000000), '-25L');
  });

  // TC-16-empty (FR-16-01)
  testWidgets('empty state', (t) async {
    await t.runAsync(() => env.settings.write(SettingKeys.hideAmounts, false));
    await pump(t);
    expect(find.byKey(const Key('portfolio_empty')), findsOneWidget);
    expect(find.text('NET WORTH'), findsOneWidget);
    await teardownApp(t);
  });

  // FR-16-02, FR-16-03, FR-16-08
  for (final dark in [false, true]) {
    testWidgets('populated (dark=$dark)', (t) async {
      await seed(t);
      await pump(t, dark: dark);
      expect(find.text('Demo Equity Fund'), findsOneWidget);
      expect(find.byKey(const Key('allocation')), findsOneWidget);
      // Class header and holding row.
      expect(find.text('+20.0%'), findsNWidgets(2));
      expect(
        t.widget<Text>(find.byKey(const Key('nw-value'))).data,
        '₹1,20,000',
      );
      await teardownApp(t);
    });
  }

  // FR-16-08 add manual holding
  testWidgets('add manual holding', (t) async {
    await t.runAsync(() => env.settings.write(SettingKeys.hideAmounts, false));
    await pump(t);
    await t.tap(find.byKey(const Key('holding-add')));
    await t.pumpAndSettle();
    expect(
      t.widget<FilledButton>(find.byKey(const Key('holding-save'))).onPressed,
      isNull,
    );
    await t.enterText(find.byKey(const Key('holding-name')), 'Gold Coin');
    await t.enterText(find.byKey(const Key('holding-value')), '5000');
    await t.pump();
    await t.tap(find.byKey(const Key('holding-save')));
    await t.pump();
    await settle(t);
    final list = await t.runAsync(holdings.list);
    expect(list!.single.name, 'Gold Coin');
    expect(list.single.valueMinor, 500000);
    await teardownApp(t);
  });

  // FR-16-08 delete with confirm
  testWidgets('delete holding', (t) async {
    await seed(t);
    await pump(t);
    await t.tap(find.text('Demo Equity Fund'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('holding-delete')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('holding-delete-confirm')));
    await t.pump();
    await settle(t);
    expect(await t.runAsync(holdings.list), isEmpty);
    await teardownApp(t);
  });

  // FR-17-19 masking
  testWidgets('amounts masked', (t) async {
    await seed(t, hide: true);
    await pump(t);
    expect(t.widget<Text>(find.byKey(const Key('nw-value'))).data, '₹••••');
    expect(find.textContaining('1,20,000'), findsNothing);
    await teardownApp(t);
  });
}

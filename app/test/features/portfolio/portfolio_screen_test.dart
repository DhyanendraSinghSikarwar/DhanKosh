import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/portfolio/data/net_worth_repository_impl.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
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

  Future<void> pump(WidgetTester t, {bool dark = false}) async {
    await t.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(env.accounts),
          transactionRepositoryProvider.overrideWithValue(env.txs),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          holdingRepositoryProvider.overrideWithValue(holdings),
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

  // TC-16-empty (FR-16-01)
  testWidgets('empty state', (t) async {
    await t.runAsync(() => env.settings.write(SettingKeys.hideAmounts, false));
    await pump(t);
    expect(find.byKey(const Key('portfolio_empty')), findsOneWidget);
    expect(find.text('Net worth'), findsOneWidget);
    await teardownApp(t);
  });

  // FR-16-02, FR-16-03, FR-16-08
  for (final dark in [false, true]) {
    testWidgets('populated (dark=$dark)', (t) async {
      await seed(t);
      await pump(t, dark: dark);
      expect(find.text('Demo Equity Fund'), findsOneWidget);
      expect(find.byKey(const Key('allocation')), findsOneWidget);
      expect(find.text('+20.0%'), findsOneWidget);
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

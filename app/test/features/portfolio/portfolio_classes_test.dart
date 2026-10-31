import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/net_worth_estimate_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/portfolio/data/net_worth_repository_impl.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_class.dart';
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

  Future<void> pump(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(420, 4000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const PortfolioScreen()),
        GoRoute(
          path: '/news',
          builder: (_, __) => const Scaffold(body: Text('news-page')),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(env.accounts),
          transactionRepositoryProvider.overrideWithValue(env.txs),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          holdingRepositoryProvider.overrideWithValue(holdings),
          netWorthEstimateProvider.overrideWith((ref) async => []),
          netWorthRepositoryProvider
              .overrideWithValue(NetWorthRepositoryImpl(env.db)),
          netWorthProvider.overrideWith(
            (ref) => Stream.value(
              const NetWorth(
                assetsMinor: 100000,
                liabilitiesMinor: 25000,
                parts: [],
                cards: [],
              ),
            ),
          ),
          maturitiesProvider.overrideWith((ref) => Stream.value([])),
          loansStateProvider.overrideWith(
            (ref) async => const LoansState(loans: [], dismissed: {}),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await settle(t);
  }

  Future<void> seedAll(WidgetTester t, {bool hide = false}) =>
      t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, hide);
        for (final c in PortfolioClass.values) {
          await holdings.addManual(
            kind: holdingKindOfClass(c),
            name: 'Item ${c.name}',
            valueMinor: 100000 + c.index * 10000,
            at: env.clock,
          );
        }
      });

  // FR-16-41
  testWidgets('every class renders chip, legend row and card', (t) async {
    await seedAll(t);
    await pump(t);
    for (final c in PortfolioClass.values) {
      expect(find.byKey(Key('class-chip-${c.name}')), findsOneWidget);
      expect(find.byKey(Key('class-card-${c.name}')), findsOneWidget);
      expect(find.byKey(Key('alloc-row-${c.name}')), findsOneWidget);
    }
    expect(find.text('Sukanya Samriddhi'), findsWidgets);
    expect(find.byKey(const Key('nw-summary')), findsOneWidget);
    await teardownApp(t);
  });

  // FR-16-41
  testWidgets('chips filter the holdings list', (t) async {
    await seedAll(t);
    await pump(t);
    await t.ensureVisible(find.byKey(const Key('class-chip-gold')));
    await t.tap(find.byKey(const Key('class-chip-gold')));
    await settle(t);
    expect(find.byKey(const Key('class-card-gold')), findsOneWidget);
    expect(find.byKey(const Key('class-card-ppf')), findsNothing);
    await t.ensureVisible(find.byKey(const Key('class-chip-all')));
    await t.tap(find.byKey(const Key('class-chip-all')));
    await settle(t);
    expect(find.byKey(const Key('class-card-ppf')), findsOneWidget);
    await teardownApp(t);
  });

  // FR-16-41
  testWidgets('legend row and donut slice focus a class, tap again clears',
      (t) async {
    await seedAll(t);
    await pump(t);
    await t.ensureVisible(find.byKey(const Key('alloc-row-nps')));
    await t.tap(find.byKey(const Key('alloc-row-nps')));
    await settle(t);
    expect(find.byKey(const Key('class-card-nps')), findsOneWidget);
    expect(find.byKey(const Key('class-card-gold')), findsNothing);
    await t.tap(find.byKey(const Key('alloc-row-nps')));
    await settle(t);
    expect(find.byKey(const Key('class-card-gold')), findsOneWidget);
    // Donut: the first slice (Stocks, 8%) starts at three o'clock and runs
    // clockwise, so its middle is about 14 degrees below the right edge.
    final c = t.getCenter(find.byKey(const Key('alloc-donut')));
    await t.tapAt(c + const Offset(52, 13));
    await settle(t);
    expect(find.byKey(const Key('class-card-stocks')), findsOneWidget);
    expect(find.byKey(const Key('class-card-gold')), findsNothing);
    await teardownApp(t);
  });

  // FR-17-19
  testWidgets('hidden amounts mask the new rows', (t) async {
    await seedAll(t, hide: true);
    await pump(t);
    expect(find.textContaining('1,00,000'), findsNothing);
    expect(find.textContaining('₹'), findsWidgets);
    await teardownApp(t);
  });

  // FR-31-40
  testWidgets('news button opens the news screen', (t) async {
    await seedAll(t);
    await pump(t);
    await t.tap(find.byKey(const Key('portfolio-news')));
    await settle(t);
    expect(find.text('news-page'), findsOneWidget);
    await teardownApp(t);
  });
}

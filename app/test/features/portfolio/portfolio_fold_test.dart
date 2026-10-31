// Portfolio shortcuts, investment list, "as of" dates and the optional NAV
// refresh toggle (FR-16-22..26). Fictional data.
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
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/investment_tx.dart';
import 'package:hisaab/features/portfolio/domain/nav_file.dart';
import 'package:hisaab/features/portfolio/domain/nav_refresh.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:parser_core/parser_core.dart' hide HoldingKind;

import '../../support/fake_ledger.dart';
import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

class _Src implements NavSource {
  int calls = 0;
  @override
  Future<String?> fetch() async {
    calls++;
    return null;
  }
}

void main() {
  late TestEnv env;
  late HoldingRepositoryImpl holdings;
  late _Src src;
  setUp(() {
    env = TestEnv();
    holdings = HoldingRepositoryImpl(env.db);
    src = _Src();
  });
  tearDown(() => env.close());

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => PortfolioScreen(
            sipSection: const Text('sip-slot', key: Key('sip-slot')),
            sipSheet: (_) => const Text('sip-sheet', key: Key('sip-sheet')),
          ),
        ),
        GoRoute(
          path: '/statements',
          builder: (_, __) => const Text('statements-page'),
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
                assetsMinor: 0,
                liabilitiesMinor: 0,
                parts: [],
                cards: [],
              ),
            ),
          ),
          maturitiesProvider.overrideWith((ref) => Stream.value([])),
          loansStateProvider.overrideWith(
            (ref) async => const LoansState(loans: [], dismissed: {}),
          ),
          navRefreshServiceProvider.overrideWithValue(
            NavRefreshService(
              holdings: holdings,
              settings: env.settings,
              source: src,
              parse: (t) async => NavFileParser.parse(t),
            ),
          ),
        ],
        child:
            MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
      ),
    );
    await settle(t);
  }

  /// Opens the title-row overflow menu and picks [key].
  Future<void> menu(WidgetTester t, String key) async {
    await t.tap(find.byKey(const Key('portfolio-more')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(Key(key)));
  }

  testWidgets(
      'overflow menu: Import statement, Add holding, Add SIP (FR-16-26)',
      (t) async {
    await t.runAsync(() => env.settings.write(SettingKeys.hideAmounts, false));
    await pump(t);
    expect(find.byKey(const Key('sip-slot')), findsOneWidget);
    await menu(t, 'shortcut-sip');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('sip-sheet')), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await menu(t, 'shortcut-holding');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(BottomSheet), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await menu(t, 'shortcut-import');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('statements-page'), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets('every value carries an as-of date (FR-16-25)', (t) async {
    await t.runAsync(() async {
      await env.settings.write(SettingKeys.hideAmounts, false);
      await holdings.addManual(
        kind: HoldingKind.mutualFund,
        name: 'Demo Equity Fund',
        valueMinor: 12000000,
        investedMinor: 10000000,
        at: DateTime.utc(2026, 10, 23, 6).millisecondsSinceEpoch,
      );
    });
    await pump(t);
    expect(find.byKey(const Key('nw-as-of')), findsOneWidget);
    expect(find.byKey(const Key('allocation-as-of')), findsOneWidget);
    // Allocation card and the newest-date note on each class card.
    expect(find.text('as of 23 Oct 2026'), findsNWidgets(2));
    expect(
      find.textContaining('Invested ₹1,00,000'),
      findsWidgets,
    );
    await teardownApp(t);
  });

  testWidgets('investment list: buys, redemptions, dividends (FR-16-25)',
      (t) async {
    await t.runAsync(() async {
      await env.settings.write(SettingKeys.hideAmounts, false);
      await holdings.addManual(
        kind: HoldingKind.mutualFund,
        name: 'Demo Equity Fund',
        valueMinor: 100,
        at: 1,
      );
      await env.ingest(
        parsed(
          amountMinor: 500000,
          type: TransactionType.investment,
          merchant: 'Demo AMC',
          category: Category.investment,
          ref: 'i1',
        ),
      );
      await env.ingest(
        parsed(
          amountMinor: 120000,
          type: TransactionType.credit,
          merchant: 'Demo AMC dividend',
          category: Category.investment,
          ref: 'i2',
        ),
      );
    });
    await pump(t);
    expect(find.byKey(const Key('investment-txs')), findsOneWidget);
    expect(find.textContaining('Buy'), findsOneWidget);
    expect(find.textContaining('Dividend'), findsOneWidget);
    await teardownApp(t);
  });

  test('investment kinds', () {
    final at = DateTime.utc(2026, 10, 5, 6);
    expect(
      investmentKind(fakeTx(1, 5, at, type: TransactionType.investment)),
      InvestmentTxKind.buy,
    );
    expect(
      investmentKind(
        fakeTx(
          2,
          5,
          at,
          type: TransactionType.investment,
          merchant: 'Redemption proceeds',
        ),
      ),
      InvestmentTxKind.redemption,
    );
    expect(
      investmentKind(fakeTx(3, 5, at, type: TransactionType.credit)),
      InvestmentTxKind.redemption,
    );
    expect(
      isInvestmentTx(fakeTx(4, 5, at, category: Category.investment)),
      isFalse,
    );
    expect(
      isInvestmentTx(
        fakeTx(
          5,
          5,
          at,
          type: TransactionType.credit,
          category: Category.investment,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('NAV refresh is off by default; toggle and Refresh now',
      (t) async {
    await t.runAsync(() => env.settings.write(SettingKeys.hideAmounts, false));
    await pump(t);
    await menu(t, 'portfolio-settings');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    expect(
      t.widget<SwitchListTile>(find.byKey(const Key('nav-toggle'))).value,
      isFalse,
    );
    expect(find.byKey(const Key('nav-now')), findsNothing);
    await t.tap(find.byKey(const Key('nav-toggle')));
    await settle(t);
    expect(
      await t.runAsync(() => env.settings.read(NavSettings.enabled)),
      isTrue,
    );
    await t.tap(find.byKey(const Key('nav-now')));
    await settle(t);
    expect(src.calls, 1);
    expect(find.text('Could not download'), findsOneWidget);
    await teardownApp(t);
  });
}

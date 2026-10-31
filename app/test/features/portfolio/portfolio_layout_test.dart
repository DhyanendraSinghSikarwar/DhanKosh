import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/bills_providers.dart';
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
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';

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
    await t.binding.setSurfaceSize(const Size(420, 2400));
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
            (ref) => Stream.value(
              const NetWorth(
                assetsMinor: 1500000,
                liabilitiesMinor: 300000,
                parts: [
                  WorthPart(
                    key: 'a',
                    label: 'HDFC Bank',
                    amountMinor: 1500000,
                    liability: false,
                    kind: PartKind.bank,
                  ),
                  WorthPart(
                    key: 'l',
                    label: 'Car loan',
                    amountMinor: 300000,
                    liability: true,
                    kind: PartKind.loan,
                  ),
                ],
                cards: [],
              ),
            ),
          ),
          maturitiesProvider.overrideWith((ref) => Stream.value([])),
          loansStateProvider.overrideWith(
            (ref) async => const LoansState(loans: [], dismissed: {}),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PortfolioScreen(),
        ),
      ),
    );
    await settle(t);
  }

  Future<void> seed(WidgetTester t) => t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, false);
        await holdings.addManual(
          kind: HoldingKind.mutualFund,
          name: 'Demo Equity Fund',
          valueMinor: 12000000,
          investedMinor: 10000000,
          at: env.clock,
        );
      });

  // FR-16-28
  testWidgets('net worth by account shows bar, legend and breakdown',
      (t) async {
    await seed(t);
    await pump(t);
    expect(find.byKey(const Key('networth-split-bar')), findsOneWidget);
    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.text('Car loan'), findsOneWidget);
    expect(find.byKey(const Key('networth-choose')), findsOneWidget);
    await teardownApp(t);
  });

  // FR-16-29, FR-16-41
  testWidgets('class chip filters the holdings list', (t) async {
    await seed(t);
    await pump(t);
    expect(find.text('Demo Equity Fund'), findsOneWidget);
    await t.tap(find.byKey(const Key('class-chip-mutualFunds')));
    await settle(t);
    expect(find.text('Demo Equity Fund'), findsOneWidget);
    await teardownApp(t);
  });

  // FR-16-27
  testWidgets('layout store hides a section', (t) async {
    await seed(t);
    await t.runAsync(
      () => env.settings.write(
        SectionLayout.key(ScreenIds.portfolio),
        SectionLayout.encode(
          SectionLayout.setVisible(
            SectionLayout.defaults(ScreenIds.portfolio),
            'allocation',
            visible: false,
          ),
        ),
      ),
    );
    await pump(t);
    expect(find.byKey(const Key('allocation')), findsNothing);
    expect(find.byKey(const Key('networth-split')), findsOneWidget);
    await teardownApp(t);
  });
}

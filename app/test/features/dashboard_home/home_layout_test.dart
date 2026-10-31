import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/dashboard_home/presentation/dashboard_home_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
import 'package:hisaab/features/theming_customisation/presentation/section_layout_editor.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

List<RouteBase> _routes() => [
      GoRoute(
        path: '/',
        builder: (_, __) => const DashboardHomeScreen(
          layoutEditor: SectionLayoutEditor(screenId: ScreenIds.home),
        ),
      ),
      GoRoute(path: '/accounts', builder: (_, __) => const SizedBox()),
    ];

/// Picks a Home overflow-menu entry (the popup's hit testing is awkward
/// under the test clock).
Future<void> _menu(WidgetTester t, String value) async {
  t
      .widget<PopupMenuButton<String>>(find.byKey(const Key('home_menu')))
      .onSelected!(value);
  await settle(t);
}

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(800, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Future<void> seed(WidgetTester t) => t.runAsync(() async {
        await env.settings.write(SettingKeys.hideAmounts, false);
        await env.settings.write(SettingKeys.smsPromptDismissed, true);
        await env.accounts.create(
          const NewAccount(
            kind: AccountKind.account,
            bankName: 'HDFC Bank',
            last4: '1234',
            balanceMinor: 5000000,
          ),
        );
        await env.ingest(
          parsed(
            amountMinor: 245050,
            time: DateTime.now().millisecondsSinceEpoch - 1000,
            ref: 'AAA111111',
          ),
        );
      });

  // FR-17-05, TC-28-16
  testWidgets('default sections show, budgets included', (t) async {
    tall(t);
    await seed(t);
    await pumpApp(t, env, _routes());
    expect(find.byKey(const Key('home_spent')), findsOneWidget);
    expect(find.byKey(const Key('home_upcoming')), findsOneWidget);
    expect(find.byKey(const Key('home_budgets')), findsOneWidget);
    expect(find.byKey(const Key('home_sync')), findsOneWidget);
    await t.tap(find.byKey(const Key('home_menu')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('home_add')), findsOneWidget);
    expect(find.byKey(const Key('home_accounts_button')), findsOneWidget);
    await _menu(t, 'edit');
    expect(find.byKey(const Key('home_edit_done')), findsOneWidget);
    await teardownApp(t);
  });

  // FR-28-19: presets are a working feature
  testWidgets('edit mode: Minimal preset hides sections', (t) async {
    tall(t);
    await seed(t);
    await pumpApp(t, env, _routes());
    await _menu(t, 'edit');
    expect(find.byKey(const Key('home_edit_card')), findsOneWidget);
    await t.tap(find.byKey(const Key('preset-Minimal')));
    await settle(t);
    final saved = await t.runAsync(
      () => env.settings.read(SectionLayout.key(ScreenIds.home)),
    );
    expect(
      SectionLayout.visibleIds(SectionLayout.resolve('home', saved)),
      ['spent', 'cashflow', 'upcoming'],
    );
    await t.tap(find.byKey(const Key('home_edit_done')));
    await settle(t);
    expect(find.byKey(const Key('home_upcoming')), findsOneWidget);
    expect(find.byKey(const Key('home_tx_1')), findsNothing);
    await teardownApp(t);
  });

  testWidgets('hiding a section in the editor persists', (t) async {
    tall(t);
    await seed(t);
    await pumpApp(t, env, _routes());
    await _menu(t, 'edit');
    await t.tap(find.byKey(const Key('section-upcoming')));
    await settle(t);
    await t.tap(find.byKey(const Key('home_edit_done')));
    await settle(t);
    expect(find.byKey(const Key('home_upcoming')), findsNothing);
    await teardownApp(t);
  });
}

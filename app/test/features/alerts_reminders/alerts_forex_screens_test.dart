import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_settings_store.dart';
import 'package:hisaab/features/alerts_reminders/presentation/alerts_reminders_screen.dart';
import 'package:hisaab/features/forex_rates/data/forex_repository_impl.dart';
import 'package:hisaab/features/forex_rates/presentation/forex_rates_screen.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import '../../support/ui_harness.dart';
import 'alerts_engine_test.dart';

void main() {
  testWidgets('alerts screen: banner, switches, percent (TC-21-11)', (t) async {
    final env = TestEnv();
    final poster = FakePoster()..enabled = false;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(env.settings),
          alertPosterProvider.overrideWithValue(poster),
        ],
        child: const MaterialApp(home: AlertsRemindersScreen()),
      ),
    );
    await settle(t);
    expect(find.byKey(const Key('alerts-off-banner')), findsOneWidget);
    expect(find.byKey(const Key('alerts-howto')), findsOneWidget);
    await t.tap(find.byKey(const Key('alerts-transactions')));
    await settle(t);
    await t.tap(find.text('95%'));
    await settle(t);
    final s = await AlertSettingsStore(env.settings).read();
    expect(s.transactionNotifications, isFalse);
    expect(s.budgetAlertPercent, 95);
    poster.enabled = true;
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(env.settings),
          alertPosterProvider.overrideWithValue(poster),
        ],
        child: const MaterialApp(home: AlertsRemindersScreen()),
      ),
    );
    await settle(t);
    expect(find.byKey(const Key('alerts-off-banner')), findsNothing);
    await teardownApp(t);
    await env.close();
  });

  testWidgets('forex screen: add, flip to All counted, delete (TC-23-09)',
      (t) async {
    final env = TestEnv();
    await env.ingest(parsed(currency: 'USD', amountMinor: 20000));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(env.db),
          forexRepositoryProvider
              .overrideWithValue(ForexRepositoryImpl(env.db)),
        ],
        child: const MaterialApp(home: ForexRatesScreen()),
      ),
    );
    await settle(t);
    expect(find.byKey(const Key('forex-need-USD')), findsOneWidget);
    await t.tap(find.byKey(const Key('forex-need-USD')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('forex-rate')), '83.1');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('forex-save')));
    await t.pumpAndSettle();
    await settle(t);
    expect(find.byKey(const Key('forex-ok-USD')), findsOneWidget);
    final del = find.byWidgetPredicate(
      (w) => w.key.toString().contains('forex-del-USD'),
    );
    expect(del, findsOneWidget);
    await t.tap(del);
    await settle(t);
    expect(find.byKey(const Key('forex-empty')), findsOneWidget);
    await teardownApp(t);
    await env.close();
  });
}

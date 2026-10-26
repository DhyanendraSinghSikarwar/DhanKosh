// SIP stepped setup and the SIP list (FR-12-19, FR-12-20).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/sip_providers.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/data/sip_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';
import 'package:hisaab/features/recurring_transactions/presentation/sip_section.dart';
import 'package:hisaab/features/recurring_transactions/presentation/sip_setup_sheet.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

void main() {
  late TestEnv env;
  late SipRepositoryImpl repo;
  setUp(() {
    env = TestEnv();
    repo = SipRepositoryImpl(env.db);
  });
  tearDown(() => env.close());

  Future<void> pump(WidgetTester t, Widget body) async {
    t.view.physicalSize = const Size(800, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(env.txs),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          sipRepositoryProvider.overrideWithValue(repo),
          holdingRepositoryProvider
              .overrideWithValue(HoldingRepositoryImpl(env.db)),
          hideAmountsProvider.overrideWith((_) => Stream.value(false)),
        ],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: body)),
        ),
      ),
    );
    await settle(t);
  }

  testWidgets('frequency -> amount -> review -> confirm saves a weekly SIP',
      (t) async {
    await pump(t, const SipSetupSheet());
    expect(find.text('Add SIP · Frequency'), findsOneWidget);
    await t.tap(find.byKey(const Key('sip-freq-weekly')));
    await t.pump();
    await t.tap(find.byKey(const Key('sip-next')));
    await t.pump();
    expect(find.text('Add SIP · Amount'), findsOneWidget);
    // Needs an amount before review.
    await t.tap(find.byKey(const Key('sip-next')));
    await t.pump();
    expect(find.byKey(const Key('sip-error')), findsOneWidget);
    await t.enterText(find.byKey(const Key('sip-name')), 'Demo Index Fund');
    await t.enterText(find.byKey(const Key('sip-amount')), '2500');
    await t.tap(find.byKey(const Key('sip-wd-5')));
    await t.pump();
    await t.tap(find.byKey(const Key('sip-next')));
    await t.pump();
    expect(find.text('Add SIP · Review'), findsOneWidget);
    expect(find.text('Every Fri'), findsOneWidget);
    expect(find.text('₹2,500.00'), findsOneWidget);
    await t.tap(find.byKey(const Key('sip-next')));
    await t.pump();
    expect(find.byKey(const Key('sip-confirm-note')), findsOneWidget);
    await t.tap(find.byKey(const Key('sip-save')));
    await settle(t);
    final saved = await t.runAsync(() => repo.watchAll().first);
    expect(saved!.single.name, 'Demo Index Fund');
    expect(saved.single.frequency, SipFrequency.weekly);
    expect(saved.single.weekday, 5);
    expect(saved.single.amountMinor, 250000);
    expect(await t.runAsync(() => env.count('transactions')), 0);
    await teardownApp(t);
  });

  testWidgets('list shows a SIP; editing in place changes the amount',
      (t) async {
    await t.runAsync(
      () => repo.add(
        const SipDraft(
          name: 'Demo Index Fund',
          amountMinor: 500000,
          frequency: SipFrequency.monthly,
          startDay: 20000,
          dayOfMonth: 5,
        ),
      ),
    );
    await pump(t, const SipSection());
    expect(find.byKey(const Key('sip-Demo Index Fund')), findsOneWidget);
    expect(find.textContaining('Monthly'), findsOneWidget);
    expect(find.textContaining('Invested'), findsOneWidget);
    await t.tap(find.byKey(const Key('sip-Demo Index Fund')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Edit SIP · Review'), findsOneWidget);
    await t.tap(find.byKey(const Key('sip-review-amount')));
    await t.pump();
    await t.enterText(find.byKey(const Key('sip-amount')), '7000');
    await t.tap(find.byKey(const Key('sip-next')));
    await t.pump();
    await t.tap(find.byKey(const Key('sip-next')));
    await t.pump();
    await t.tap(find.byKey(const Key('sip-save')));
    await settle(t);
    final saved = await t.runAsync(() => repo.watchAll().first);
    expect(saved!.single.amountMinor, 700000);
    await teardownApp(t);
  });

  testWidgets('hidden when there are no SIPs unless asked', (t) async {
    await pump(t, const SipSection());
    expect(find.byKey(const Key('sip-section')), findsNothing);
    await pump(t, const SipSection(showEmpty: true));
    expect(find.byKey(const Key('sip-empty')), findsOneWidget);
    await teardownApp(t);
  });
}

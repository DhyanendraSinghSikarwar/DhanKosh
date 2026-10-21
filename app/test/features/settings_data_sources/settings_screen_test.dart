import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/settings_data_sources/domain/sample_data.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_data_sources_screen.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';

import '../../support/pipeline_fakes.dart';

void main() {
  late PipelineHarness h;
  late ProviderContainer c;

  Future<void> pump(
    WidgetTester t, {
    bool granted = true,
    List<InboxSms> inbox = const [],
  }) async {
    h = PipelineHarness(
      permission: FakePermission(granted: granted),
      inbox: inbox,
    );
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 3000);
    addTearDown(t.view.reset);
    c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: SettingsDataSourcesScreen()),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump();
  }

  Future<void> tapAsync(WidgetTester t, Key k) async {
    await t.runAsync(() async {
      await t.tap(find.byKey(k));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
  }

  tearDown(() => h.dispose());

  testWidgets('shows status and permission card when SMS is off (FR-26-03)',
      (t) async {
    await pump(t, granted: false);
    expect(find.text('Not allowed'), findsOneWidget);
    expect(find.byKey(const Key('grant-sms')), findsOneWidget);
    final scan = t.widget<FilledButton>(find.byKey(const Key('scan-now')));
    expect(scan.onPressed, isNull);
  });

  testWidgets('scan now reports a summary and last scan (FR-26-03)', (t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await pump(
      t,
      inbox: [
        InboxSms(
          sender: 'VM-HDFCBK',
          body: 'Rs.1,250.00 debited from A/c XX1234 on 20-10-26 '
              'UPI Ref 000000000001 to DEMO STORE',
          receivedAt: now - 1000,
          sentAt: now - 1000,
        ),
      ],
    );
    expect(find.text('Allowed'), findsOneWidget);
    await tapAsync(t, const Key('scan-now'));
    for (var i = 0;
        i < 50 && find.byKey(const Key('scan-result')).evaluate().isEmpty;
        i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
    }
    expect(find.textContaining('1 new'), findsWidgets);
    expect(find.byKey(const Key('scan-result')), findsOneWidget);
    expect(find.textContaining('Last scan: just now'), findsOneWidget);
  });

  testWidgets('paste import shows what was parsed or why not (FR-26-26)',
      (t) async {
    await pump(t);
    await t.enterText(
      find.byKey(const Key('paste-body')),
      'Rs.320.00 debited from A/c XX1234 on 20-10-26 '
      'UPI Ref 000000000002 to DEMO CAFE',
    );
    await tapAsync(t, const Key('paste-run'));
    expect(find.textContaining('Added: debit ₹320.00'), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('paste-body')),
      '123456 is your OTP. Do not share.',
    );
    await tapAsync(t, const Key('paste-run'));
    expect(find.textContaining('Ignored'), findsOneWidget);
  });

  testWidgets('sample data and clear all (FR-26-27, FR-26-28)', (t) async {
    await pump(t);
    final txs = c.read(transactionRepositoryProvider);
    await tapAsync(t, const Key('add-sample'));
    expect(
      find.text('Added ${SampleData.count} sample transactions.'),
      findsOneWidget,
    );
    expect(await t.runAsync(() => txs.watchRecent(100).first), hasLength(25));
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('clear-all')));
    });
    await t.pump();
    await tapAsync(t, const Key('clear-confirm'));
    expect(find.text('All data cleared.'), findsOneWidget);
    expect(await t.runAsync(() => txs.watchRecent(100).first), isEmpty);
  });

  testWidgets('hide amounts toggle persists (FR-26-29)', (t) async {
    await pump(t);
    final settings = c.read(settingsRepositoryProvider);
    expect(
      await t.runAsync(() => settings.read(SettingKeys.hideAmounts)),
      isTrue,
    );
    await tapAsync(t, const Key('hide-amounts'));
    expect(
      await t.runAsync(() => settings.read(SettingKeys.hideAmounts)),
      isFalse,
    );
  });
}

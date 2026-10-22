import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_sms_card.dart';

import '../../support/pipeline_fakes.dart';
import '../../support/ui_harness.dart';

// TC-01-11 / FR-01-13.
void main() {
  late PipelineHarness h;
  setUp(() => h = PipelineHarness());
  tearDown(() => h.dispose());

  Future<ProviderContainer> pump(WidgetTester t) async {
    final c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: HomeSmsCard())),
      ),
    );
    await settle(t);
    return c;
  }

  testWidgets('shown while missing; Not now hides and persists', (t) async {
    await pump(t);
    expect(find.byKey(const Key('grant-sms')), findsOneWidget);
    await t.tap(find.byKey(const Key('sms-not-now')));
    await settle(t);
    expect(find.byKey(const Key('grant-sms')), findsNothing);
    // A rebuilt app keeps it hidden.
    await t.pumpWidget(const SizedBox());
    await pump(t);
    expect(find.byKey(const Key('grant-sms')), findsNothing);
    await teardownApp(t);
  });

  testWidgets('hidden when granted; Allow asks', (t) async {
    await pump(t);
    await t.tap(find.byKey(const Key('grant-sms')));
    await settle(t);
    expect(h.permission.granted, isTrue);
    expect(find.byKey(const Key('grant-sms')), findsNothing);
    await teardownApp(t);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/app.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/features/onboarding_permissions/presentation/welcome_screen.dart';

import '../../support/pipeline_fakes.dart';

void main() {
  late PipelineHarness h;
  setUp(() => h = PipelineHarness());
  tearDown(() => h.dispose());

  Future<ProviderContainer> pump(WidgetTester t, Widget home) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 2400);
    addTearDown(t.view.reset);
    final c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: home),
      ),
    );
    return c;
  }

  testWidgets('continue needs name and 10 digits (FR-01-04)', (t) async {
    await pump(t, const WelcomeScreen());
    FilledButton btn() =>
        t.widget<FilledButton>(find.byKey(const Key('welcome-continue')));
    expect(btn().onPressed, isNull);
    await t.enterText(find.byKey(const Key('welcome-name')), 'Demo User');
    await t.enterText(find.byKey(const Key('welcome-phone')), '98765');
    await t.pump();
    expect(btn().onPressed, isNull);
    await t.enterText(find.byKey(const Key('welcome-phone')), '9876543210');
    await t.pump();
    expect(btn().onPressed, isNotNull);
    expect(find.text('Your data never leaves this phone.'), findsOneWidget);
  });

  testWidgets('finish seals identity then profile, then SMS ask (FR-01-06)',
      (t) async {
    final c = await pump(t, const WelcomeScreen());
    await t.enterText(find.byKey(const Key('welcome-name')), 'Demo User');
    await t.enterText(find.byKey(const Key('welcome-phone')), '9876543210');
    await t.pump();
    await t.tap(find.byKey(const Key('welcome-continue')));
    await t.pump();
    await t.enterText(find.byKey(const Key('welcome-alt-name')), 'D User');
    await t.enterText(find.byKey(const Key('welcome-pan')), 'abcde1234f');
    await t.pump();
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('welcome-finish')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pump();
    final id = await t.runAsync(c.read(identityRepositoryProvider).read);
    expect(id!.altName, 'D User');
    expect(id.pan, 'ABCDE1234F');
    final p = await t.runAsync(c.read(profileRepositoryProvider).read);
    expect(p!.name, 'Demo User');
    expect(p.phone, '+91 9876543210');
    // FR-01-07: alternates never reach plain settings.
    expect(find.byKey(const Key('grant-sms')), findsOneWidget);
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('grant-sms')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pump();
    expect(h.permission.granted, isTrue);
    expect(find.text('SMS access allowed'), findsOneWidget);
  });

  testWidgets('blocked permission shows restricted-settings steps (FR-01-10)',
      (t) async {
    h.permission.blocked = true;
    final c = await pump(t, const WelcomeScreen());
    await t.enterText(find.byKey(const Key('welcome-name')), 'Demo User');
    await t.enterText(find.byKey(const Key('welcome-phone')), '9876543210');
    await t.pump();
    await t.tap(find.byKey(const Key('welcome-continue')));
    await t.pump();
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('welcome-skip-details')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pump();
    await t.runAsync(c.read(smsPermissionProvider.notifier).refresh);
    await t.pump();
    expect(find.textContaining('Allow restricted settings'), findsOneWidget);
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('grant-sms')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(h.permission.opened, 1);
  });

  testWidgets('app shows Welcome until onboarding is done (FR-01-01)',
      (t) async {
    final c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(container: c, child: const HisaabApp()),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('welcome-name')), findsOneWidget);
  });
}

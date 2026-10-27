import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/app.dart';
import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/onboarding_permissions/presentation/welcome_screen.dart';

import '../../support/email_fakes.dart';
import '../../support/pipeline_fakes.dart';

void main() {
  late PipelineHarness h;
  setUp(() => h = PipelineHarness());
  tearDown(() => h.dispose());

  Future<ProviderContainer> pump(
    WidgetTester t,
    Widget home, {
    List<Override> extra = const [],
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 2400);
    addTearDown(t.view.reset);
    final c = ProviderContainer(overrides: [...h.overrides, ...extra]);
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

  // FR-01-03: email sign-in verified by a mailed code; nothing is saved
  // before the code is typed.
  testWidgets('email sign-in sends a code, verifies it, seeds the profile',
      (t) async {
    final imap = FakeImap();
    final smtp = FakeSmtp();
    final c = await pump(
      t,
      const WelcomeScreen(),
      extra: [
        imapClientProvider.overrideWithValue(imap),
        mailSenderProvider.overrideWithValue(smtp),
      ],
    );
    Future<void> tapAsync(String key) async {
      await t.runAsync(() async {
        await t.tap(find.byKey(Key(key)));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await t.pump();
    }

    await t.ensureVisible(find.byKey(const Key('welcome-use-email')));
    await tapAsync('welcome-use-email');
    await t.enterText(find.byKey(const Key('welcome-name')), 'Demo User');
    await t.enterText(find.byKey(const Key('welcome-email')), 'demo@gmail.com');
    await t.enterText(
      find.byKey(const Key('welcome-email-password')),
      'abcd efgh',
    );
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('welcome-send-code')));
    await tapAsync('welcome-send-code');
    expect(smtp.lastTo, 'demo@gmail.com');
    expect(find.byKey(const Key('welcome-code')), findsOneWidget);
    expect(h.secure.map, isEmpty);

    await t.enterText(find.byKey(const Key('welcome-code')), '000000');
    await t.pump();
    await tapAsync('welcome-verify');
    expect(find.text('That code does not match.'), findsOneWidget);
    expect(h.secure.map, isEmpty);

    await t.enterText(find.byKey(const Key('welcome-code')), smtp.lastCode);
    await t.pump();
    await tapAsync('welcome-verify');
    expect(h.secure.map['email_app_password:demo@gmail.com'], 'abcdefgh');
    await t.ensureVisible(find.byKey(const Key('welcome-skip-details')));
    await tapAsync('welcome-skip-details');
    final p = await t.runAsync(c.read(profileRepositoryProvider).read);
    expect(p!.name, 'Demo User');
    expect(p.email, 'demo@gmail.com');
    expect(p.phone, isNull);
  });

  testWidgets('a refused login sends no code (FR-01-03)', (t) async {
    final imap = FakeImap()..error = const AuthFailure('x');
    final smtp = FakeSmtp();
    await pump(
      t,
      const WelcomeScreen(),
      extra: [
        imapClientProvider.overrideWithValue(imap),
        mailSenderProvider.overrideWithValue(smtp),
      ],
    );
    await t.ensureVisible(find.byKey(const Key('welcome-use-email')));
    await t.tap(find.byKey(const Key('welcome-use-email')));
    await t.pump();
    await t.enterText(find.byKey(const Key('welcome-name')), 'Demo User');
    await t.enterText(find.byKey(const Key('welcome-email')), 'demo@gmail.com');
    await t.enterText(find.byKey(const Key('welcome-email-password')), 'pw');
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('welcome-send-code')));
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('welcome-send-code')));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await t.pump();
    expect(find.textContaining('app password'), findsWidgets);
    expect(smtp.sent, 0);
    expect(find.byKey(const Key('welcome-code')), findsNothing);
  });
}

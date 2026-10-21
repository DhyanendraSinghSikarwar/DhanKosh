import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';
import 'package:hisaab/features/email_ingestion/presentation/email_settings_screen.dart';

import '../../support/email_fakes.dart';
import '../../support/pipeline_fakes.dart';

void main() {
  late PipelineHarness h;
  late FakeImap imap;

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await t.pump();
  }

  Future<void> pump(WidgetTester t) async {
    h = PipelineHarness();
    imap = FakeImap();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 3000);
    addTearDown(t.view.reset);
    final c = ProviderContainer(
      overrides: [...h.overrides, imapClientProvider.overrideWithValue(imap)],
    );
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: EmailSettingsScreen()),
      ),
    );
    await settle(t);
  }

  Future<void> tap(WidgetTester t, String key) async {
    await t.runAsync(() async {
      await t.tap(find.byKey(Key(key)));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
  }

  Future<void> fill(WidgetTester t) async {
    await t.enterText(find.byKey(const Key('email-address')), 'me@gmail.com');
    await t.enterText(find.byKey(const Key('email-password')), 'abcd efgh');
    await t.pump();
  }

  String message(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('email-message'))).data!;

  tearDown(() => h.dispose());

  testWidgets('empty form asks for input, how-to is shown (FR-03-07)',
      (t) async {
    await pump(t);
    expect(find.text('Test connection'), findsOneWidget);
    expect(find.textContaining('2-Step Verification'), findsOneWidget);
    await tap(t, 'email-save');
    expect(message(t), 'Enter a full email address');
    expect(h.secure.map, isEmpty);
  });

  testWidgets('test connection maps failures to short messages (FR-03-02)',
      (t) async {
    await pump(t);
    await fill(t);
    await tap(t, 'email-test');
    expect(message(t), 'Connected.');
    imap.error = const AuthFailure('x');
    await tap(t, 'email-test');
    expect(message(t), contains('app password'));
    imap.error = const NetworkFailure('x');
    await tap(t, 'email-test');
    expect(message(t), contains('reach'));
    expect(h.secure.map, isEmpty); // testing never saves
  });

  testWidgets('save, sync now, sender edit, disconnect (FR-03-22)', (t) async {
    await pump(t);
    await fill(t);
    await tap(t, 'email-save');
    expect(find.byKey(const Key('email-sync')), findsOneWidget);
    expect(find.text('me@gmail.com'), findsOneWidget);
    expect(h.secure.map.values, contains('abcdefgh'));

    imap.mails = [
      const RawEmail(
        id: 'imap:<a@x>',
        from: 'HDFC Bank <alerts@hdfcbank.net>',
        subject: 'Alert',
        receivedAt: 1790310600000,
        plain: 'Dear Customer,\n\nRs.450.00 has been debited from account '
            '**1234 to VPA shop@icici DEMO STORE on 25-09-26.\n\n'
            'Your UPI transaction reference number is 000000000001.\n',
      ),
    ];
    await tap(t, 'email-sync');
    expect(
      t.widget<Text>(find.byKey(const Key('email-last-report'))).data,
      startsWith('full: 1 emails, 1 transactions (1 new'),
    );

    await t.enterText(
      find.byKey(const Key('email-sender-input')),
      'mybank.example',
    );
    await tap(t, 'email-sender-add');
    expect(
      find.byKey(const Key('email-sender-mybank.example')),
      findsOneWidget,
    );
    await tap(t, 'email-sender-reset');
    expect(find.byKey(const Key('email-sender-mybank.example')), findsNothing);

    await tap(t, 'email-disconnect');
    await tap(t, 'email-disconnect-confirm');
    expect(find.byKey(const Key('email-sync')), findsNothing);
    expect(h.secure.map['email_app_password'], '');
  });

  testWidgets('revoked login shows Sign in again (FR-03-18)', (t) async {
    await pump(t);
    await fill(t);
    await tap(t, 'email-save');
    imap.error = const AuthFailure('x');
    await tap(t, 'email-sync');
    expect(
      t.widget<Text>(find.byKey(const Key('email-status'))).data,
      'Sign in again',
    );
    expect(find.byKey(const Key('email-password')), findsOneWidget);
  });
}

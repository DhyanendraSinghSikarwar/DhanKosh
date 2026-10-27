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
  late FakeSmtp smtp;

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await t.pump();
  }

  Future<void> pump(WidgetTester t) async {
    h = PipelineHarness();
    imap = FakeImap();
    smtp = FakeSmtp();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 3000);
    addTearDown(t.view.reset);
    final c = ProviderContainer(
      overrides: [
        ...h.overrides,
        imapClientProvider.overrideWithValue(imap),
        mailSenderProvider.overrideWithValue(smtp),
      ],
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

  /// Fill the form, send the code and type it back (FR-03-03).
  Future<void> connect(
    WidgetTester t, {
    String address = 'me@gmail.com',
  }) async {
    await t.enterText(find.byKey(const Key('email-address')), address);
    await t.enterText(find.byKey(const Key('email-password')), 'abcd efgh');
    await t.pump();
    await tap(t, 'email-send-code');
    await t.enterText(find.byKey(const Key('email-code')), smtp.lastCode);
    await t.pump();
    await tap(t, 'email-verify');
  }

  String message(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('email-message'))).data!;

  tearDown(() => h.dispose());

  testWidgets('empty form asks for input, how-to is shown (FR-03-07)',
      (t) async {
    await pump(t);
    expect(find.text('Test connection'), findsOneWidget);
    expect(find.textContaining('2-Step Verification'), findsOneWidget);
    await tap(t, 'email-send-code');
    expect(message(t), 'Enter a full email address');
    expect(smtp.sent, 0);
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

  testWidgets('code gate: nothing is saved until the code is typed (FR-03-03)',
      (t) async {
    await pump(t);
    await fill(t);
    await tap(t, 'email-send-code');
    expect(smtp.lastTo, 'me@gmail.com');
    expect(smtp.lastPassword, 'abcdefgh');
    expect(find.byKey(const Key('email-code')), findsOneWidget);
    expect(h.secure.map, isEmpty);
    await t.enterText(find.byKey(const Key('email-code')), '000000');
    await t.pump();
    await tap(t, 'email-verify');
    expect(message(t), contains('does not match'));
    expect(h.secure.map, isEmpty);
    await t.enterText(find.byKey(const Key('email-code')), smtp.lastCode);
    await t.pump();
    await tap(t, 'email-verify');
    expect(find.byKey(const Key('email-account-me@gmail.com')), findsOneWidget);
    expect(h.secure.map['email_app_password:me@gmail.com'], 'abcdefgh');
  });

  testWidgets('two mailboxes, switch off, sync both, remove (FR-03-06)',
      (t) async {
    await pump(t);
    await connect(t);
    await connect(t, address: 'other@yahoo.com');
    expect(find.byKey(const Key('email-account-me@gmail.com')), findsOneWidget);
    expect(
      find.byKey(const Key('email-account-other@yahoo.com')),
      findsOneWidget,
    );
    await tap(t, 'email-sync');
    expect(imap.fetches, 2);
    await tap(t, 'email-enabled-other@yahoo.com');
    expect(
      t
          .widget<Text>(find.byKey(const Key('email-status-other@yahoo.com')))
          .data,
      'Off',
    );
    await tap(t, 'email-sync');
    expect(imap.fetches, 3);
    await tap(t, 'email-remove-other@yahoo.com');
    await tap(t, 'email-remove-confirm');
    expect(
      find.byKey(const Key('email-account-other@yahoo.com')),
      findsNothing,
    );
    expect(h.secure.map['email_app_password:other@yahoo.com'], '');
    expect(find.byKey(const Key('email-account-me@gmail.com')), findsOneWidget);
  });

  testWidgets('provider guides name the steps (FR-03-07)', (t) async {
    await pump(t);
    await tap(t, 'email-provider-outlook');
    expect(find.textContaining('Two-step verification'), findsOneWidget);
    await tap(t, 'email-provider-icloud');
    expect(find.textContaining('App-Specific'), findsOneWidget);
  });

  testWidgets('save, sync now, sender edit, remove (FR-03-22)', (t) async {
    await pump(t);
    await connect(t);
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
      t
          .widget<Text>(find.byKey(const Key('email-last-report-me@gmail.com')))
          .data,
      contains('full: 1 emails, 1 transactions (1 new'),
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

    await tap(t, 'email-remove-me@gmail.com');
    await tap(t, 'email-remove-confirm');
    expect(find.byKey(const Key('email-sync')), findsNothing);
    expect(h.secure.map['email_app_password:me@gmail.com'], '');
  });

  testWidgets('revoked login shows Sign in again (FR-03-18)', (t) async {
    await pump(t);
    await connect(t);
    imap.error = const AuthFailure('x');
    await tap(t, 'email-sync');
    expect(
      t.widget<Text>(find.byKey(const Key('email-status-me@gmail.com'))).data,
      'Sign in again',
    );
    expect(find.byKey(const Key('email-password')), findsOneWidget);
  });
}

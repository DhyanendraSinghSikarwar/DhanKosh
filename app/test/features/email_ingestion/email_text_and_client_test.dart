import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' as em;
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/data/enough_mail_imap_client.dart';
import 'package:hisaab/features/email_ingestion/domain/email_text.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:mocktail/mocktail.dart';

class _MockImap extends Mock implements em.ImapClient {}

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));

  group('EmailText (FR-03-15)', () {
    test('plain of 30+ chars wins over html', () {
      final p = 'x' * 40;
      expect(EmailText.choose(p, '<p>other</p>'), p);
    });

    test('short plain falls back to html, keeping boundaries', () {
      final t = EmailText.choose(
        'hi',
        '<style>a{}</style><table><tr><td>Amt</td><td>Rs.5&nbsp;&amp;</td></tr>'
            '<tr><td>Ref</td><td>9</td></tr></table>line<br>two&#8377;',
      );
      expect(t, contains('Amt Rs.5 &'));
      expect(t.split('\n').length, greaterThan(2));
      expect(t, contains('₹'));
      expect(t, isNot(contains('a{}')));
    });

    test(
      'short plain with no html stays',
      () => expect(EmailText.choose(' hi ', null), 'hi'),
    );
  });

  group('EnoughMailImapClient error mapping (FR-03-02)', () {
    final account = EmailAccount.forAddress('me@gmail.com');

    EnoughMailImapClient clientWith(_MockImap m) =>
        EnoughMailImapClient(create: () => m);

    _MockImap mock() {
      final m = _MockImap();
      when(m.logout).thenAnswer((_) async {});
      when(m.disconnect).thenAnswer((_) async {});
      return m;
    }

    test('auth wording maps to AuthFailure', () {
      final m = mock();
      expect(
        EnoughMailImapClient.mapError(
          em.ImapException(m, 'AUTHENTICATIONFAILED'),
        ),
        isA<AuthFailure>(),
      );
    });

    test('socket error is a NetworkFailure, handshake a TlsFailure', () async {
      for (final (err, type) in <(Object, Matcher)>[
        (const SocketException('x'), isA<NetworkFailure>()),
        (TimeoutException('x'), isA<NetworkFailure>()),
        (const HandshakeException('x'), isA<TlsFailure>()),
      ]) {
        final m = mock();
        when(
          () => m.connectToServer(
            any(),
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(err);
        await expectLater(
          clientWith(m).testLogin(account, 'pw'),
          throwsA(type),
        );
      }
    });

    test('failure messages never carry server text', () {
      final f = EnoughMailImapClient.mapError(
        const SocketException('secret@host 10.0.0.1'),
      );
      expect(f.message, isNot(contains('secret')));
    });
  });
}

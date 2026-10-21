// User feedback: the user's mobile number (last four 6810) showed up as an
// extra account at Axis and SBI, and money sent to someone else's account
// (payee 9876) showed up as income in the payee's "account". Port of
// AccountAttributionTest (FR-06-07).
// Long messages are written as adjacent literals so each fixture reads as
// one message.
// ignore_for_file: no_adjacent_strings_in_list

import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

void main() {
  final registry = ParserRegistry.standard();
  ParsedTransaction? parse(
    String body,
    String sender, [
    Source source = Source.sms,
  ]) =>
      registry.parse(body, sender, receivedAt, source);

  // ---- Bug 1: masked mobile numbers and UPI IDs are not accounts ----

  group('axis - the account is 1234, never the mobile 6810', () {
    for (final body in [
      'INR 500.00 debited A/c no. XX1234 05-10-26 12:30:11 '
          'UPI/P2A/527812345678/ANIL KUMAR Not you? SMS BLOCKUPI Cust ID to '
          '919951860002 Axis Bank',
      'INR 500.00 debited A/c no. XX1234 05-10-26 12:30:11 '
          'UPI/P2A/527812345678/ANIL KUMAR from 9876546810@axl Not you? '
          'SMS BLOCKUPI Cust ID to 919951860002 Axis Bank',
      'Payment of INR 500.00 from XXXXXX6810@ybl to ANIL KUMAR. Debited from '
          'XX1234 on 05-10-26. UPI Ref 527812345678 - Axis Bank',
      'Your registered mobile XXXXXX6810: INR 500.00 debited from XX1234 on '
          '05-10-26. UPI Ref 527812345678 - Axis Bank',
      'INR 500.00 sent from 98XXXXX6810@axl via UPI. Debited from XX1234 on '
          '05-10-26. UPI Ref 527812345678 - Axis Bank',
    ]) {
      test(body, () {
        final tx = parse(body, 'AX-AXISBK-S');
        expect(tx, isNotNull, reason: body);
        expect(tx!.type, TransactionType.debit);
        expect(tx.accountLast4, '1234');
      });
    }
  });

  group('sbi - the account is 1234, never the mobile 6810', () {
    for (final body in [
      'Dear UPI user A/C X1234 debited by 500.0 on date 05Oct26 trf to ANIL '
          'KUMAR Refno 527812345678. If not u? call 1800111109. -SBI',
      'Dear UPI user, UPI ID 9xxxxxx810@sbi: A/C X1234 debited by 500.0 on '
          'date 05Oct26 trf to ANIL KUMAR Refno 527812345678. If not u? call '
          '1800111109. -SBI',
      'Dear SBI User, registered mobile no. XXXXXX6810. Your a/c XX1234 '
          'debited by Rs.500 on 05Oct26 trf to ANIL KUMAR Ref No '
          '527812345678 -SBI',
      'Rs.500 debited from XXXXXX6810@ybl on 05Oct26 to ANIL KUMAR, A/C '
          'X1234. Refno 527812345678 -SBI',
    ]) {
      test(body, () {
        final tx = parse(body, 'VM-SBIUPI-S');
        expect(tx, isNotNull, reason: body);
        expect(tx!.type, TransactionType.debit);
        expect(tx.accountLast4, '1234');
      });
    }
  });

  test("a message whose only number is the user's UPI ID has no account", () {
    final tx = parse(
      'Rs.500 debited via UPI from XXXXXX6810@ybl on 05Oct26 to ANIL KUMAR. '
          'Refno 527812345678 -SBI',
      'VM-SBIUPI-S',
    );
    expect(tx, isNotNull);
    expect(tx!.accountLast4, isNull);
  });

  group('masked mobile numbers and UPI IDs are never accounts', () {
    for (final text in [
      'UPI ID 9xxxxxx810@sbi debited INR 500',
      'debited INR 500. VPA XXXXXX6810@ybl',
      '9876546810@axl debited INR 500',
      'registered mobile number XXXXXX6810 debited INR 500',
      'mob no XX6810 debited INR 500',
      'Mobile No.: XXXXXX6810 debited INR 500',
      'INR 500 debited. Call +91 XXXXXX6810',
    ]) {
      test(text, () {
        expect(AccountExtractor.extract(text), isNull);
        expect(AccountExtractor.extract(text, TransactionType.debit), isNull);
      });
    }
  });

  test('a labelled account after a phone mention is still found', () {
    expect(
      AccountExtractor.extract(
        'registered mobile XXXXXX6810 A/c XX1234 debited INR 500',
        TransactionType.debit,
      )?.last4,
      '1234',
    );
    expect(
      AccountExtractor.extract(
        'mob no XX6810, INR 500 debited from XX1234',
        TransactionType.debit,
      )?.last4,
      '1234',
    );
  });

  // ---- Bug 2: money sent to another person's account is a debit ----

  group("money sent to a beneficiary is a debit from the user's account", () {
    for (final body in [
      'NEFT of Rs 5,000.00 credited to Beneficiary A/c XXXX9876 (ANIL KUMAR) '
          'from your A/c XX1234 on 05-10-26. UTR AXISN52026100512345',
      'Rs.5000 has been credited to beneficiary account XXXXXXXX9876 from '
          'your A/c XX1234 via IMPS. IMPS Ref No 627812345678',
      "INR 5,000.00 credited to ANIL KUMAR's account XX9876 from A/c no. "
          'XX1234 via IMPS. Ref 627812345678',
      'Your fund transfer of INR 5,000 from A/c XX1234 to A/c XX9876 is '
          'successful. IMPS Ref No 627812345678',
    ]) {
      test(body, () {
        final tx = parse(body, 'AX-AXISBK-S');
        expect(tx, isNotNull, reason: body);
        expect(tx!.type, TransactionType.debit);
        expect(tx.accountLast4, '1234');
      });
    }
  });

  group("when only the payee's account is written there is no account", () {
    for (final body in [
      'Rs.5000 has been credited to beneficiary account XXXXXXXX9876 via '
          'IMPS. IMPS Ref No 627812345678',
      'Your fund transfer of INR 5,000 to A/c XX9876 is successful. IMPS Ref '
          'No 627812345678',
      'IMPS: Rs 5000 sent to a/c 9876 on 05-10-26. Ref 627812345678',
      'NEFT of Rs 5,000.00 credited to Beneficiary A/c XXXX9876 (ANIL KUMAR) '
          'on 05-10-26. UTR SBIN52026100512345',
    ]) {
      test(body, () {
        final tx = parse(body, 'VM-SBIINB-S');
        expect(tx, isNotNull, reason: body);
        expect(tx!.type, TransactionType.debit);
        expect(tx.accountLast4, isNull);
      });
    }
  });

  test('outgoing transfers are classified as debits', () {
    expect(
      TypeClassifier.classify(
        'NEFT of INR 5,000.00 credited to Beneficiary A/c XXXX9876',
      ),
      TransactionType.debit,
    );
    expect(
      TypeClassifier.classify(
        'INR 5000 has been credited to beneficiary account XXXXXXXX9876 via '
        'IMPS',
      ),
      TransactionType.debit,
    );
    expect(
      TypeClassifier.classify("INR 5000 credited to ANIL KUMAR's account"),
      TransactionType.debit,
    );
    expect(
      TypeClassifier.classify(
        'Your fund transfer of INR 5,000 to A/c XX9876 is successful',
      ),
      TransactionType.debit,
    );
    // Money coming in is still a credit.
    expect(
      TypeClassifier.classify(
        'INR 5000 credited to your A/c XX1234 from ANIL KUMAR',
      ),
      TransactionType.credit,
    );
    expect(
      TypeClassifier.classify(
        'INR 5000 credited to A/c XX1234 by transfer from ANIL KUMAR',
      ),
      TransactionType.credit,
    );
  });

  test('beneficiary numbers are skipped whatever the direction', () {
    expect(
      AccountExtractor.extract('credited to Beneficiary A/c XXXX9876'),
      isNull,
    );
    expect(
      AccountExtractor.extract(
        'credited to Beneficiary A/c XXXX9876',
        TransactionType.credit,
      ),
      isNull,
    );
    expect(
      AccountExtractor.extract(
        'in favour of a/c XX9876 from your A/c XX1234',
        TransactionType.credit,
      )?.last4,
      '1234',
    );
  });
}

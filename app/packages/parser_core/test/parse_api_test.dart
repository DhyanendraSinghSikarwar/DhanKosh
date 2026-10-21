// The public entry point: sealed ParseResult for SMS, email and app
// notifications (FR-06-05, FR-06-19).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

void main() {
  test('an SMS is parsed', () {
    final r = parse(
      Source.sms,
      'VM-HDFCBK',
      'Rs.349.00 spent via HDFC Bank Card xx5678 at UBER INDIA on '
          '2026-09-20:22:01:45 Avl Lmt: Rs 1,23,456.00',
      receivedAt,
    );
    expect(r, isA<Parsed>());
    expect(r.transaction!.amountMinor, 34900);
  });

  test('an email is parsed', () {
    final r = parse(
      Source.email,
      'HDFC Bank InstaAlerts <alerts@hdfcbank.net>',
      'Dear Customer,\nRs.450.00 has been debited from account **1234 to VPA '
          'swiggy@icici SWIGGY on 25-09-26.\nYour UPI transaction reference '
          'number is 526812345678.',
      receivedAt,
    );
    expect(r, isA<Parsed>());
    expect(r.transaction!.referenceNumber, '526812345678');
  });

  test('an OTP is rejected with the rule that fired', () {
    final r = parse(
      Source.sms,
      'VM-HDFCBK',
      '123456 is your OTP for txn of INR 1,500.00 at AMAZON on HDFC Bank card '
          'ending 5678. Valid for 5 mins.',
      receivedAt,
    );
    expect(r, isA<Rejected>());
    expect((r as Rejected).reason, 'otp');
    expect(r.transaction, isNull);
  });

  test('other rejection reasons surface', () {
    String? why(String body) {
      final r = parse(Source.sms, 'VM-HDFCBK', body, receivedAt);
      return r is Rejected ? r.reason : null;
    }

    expect(
      why(
        'Rs.599.00 will be debited from HDFC Bank A/c XX1234 on 01-10-26 '
        'towards NETFLIX mandate.',
      ),
      'future',
    );
    expect(
      why(
        'Transaction of Rs.500.00 on HDFC Bank Card x5678 at FLIPKART has '
        'been declined due to insufficient balance.',
      ),
      'failed',
    );
  });

  test('an unknown sender is not a transaction', () {
    final r = parse(
      Source.sms,
      'VM-AMAZON',
      'Rs 450.00 debited from A/c XX1234 on 25-09-26 to SWIGGY',
      receivedAt,
    );
    expect(r, isA<NotATransaction>());
    expect((r as NotATransaction).reason, 'unknown sender');
  });

  test('a short or amount-less message is not a transaction', () {
    expect(
      parse(Source.sms, 'VM-HDFCBK', 'Hi', receivedAt),
      isA<NotATransaction>(),
    );
    expect(
      parse(
        Source.sms,
        'VM-HDFCBK',
        'Your HDFC Bank account statement is available online now',
        receivedAt,
      ),
      isA<NotATransaction>(),
    );
  });

  test('an app notification is read with the notification rules', () {
    final paid = parse(
      Source.app,
      'Google Pay',
      '₹250 paid to Swiggy. Payment successful',
      1760000000000,
    );
    expect(paid, isA<Parsed>());
    expect(paid.transaction!.source, Source.app);
    expect(paid.transaction!.merchant, 'Swiggy');
    final otp = parse(Source.app, 'BHIM', '123456 is your OTP to pay ₹500', 1);
    expect(otp, isA<Rejected>());
    final noise = parse(Source.app, 'PhonePe', 'New message from Hi', 1);
    expect(noise, isA<NotATransaction>());
  });

  test('screenshots, manual entries and statements are not read here', () {
    for (final s in [Source.screenshot, Source.manual, Source.statement]) {
      expect(
        parse(s, 'x', 'Paid Rs 250 to Ravi', receivedAt),
        isA<NotATransaction>(),
      );
    }
  });

  test('parsing is deterministic for fixed inputs (FR-06-19)', () {
    const body = 'Rs.349.00 spent via HDFC Bank Card xx5678 at UBER INDIA on '
        '2026-09-20:22:01:45 Avl Lmt: Rs 1,23,456.00';
    final a = parse(Source.sms, 'VM-HDFCBK', body, receivedAt).transaction;
    final b = parse(Source.sms, 'VM-HDFCBK', body, receivedAt).transaction;
    expect(a, b);
  });

  test('10,000 mixed messages parse within a budget (TC-06-25)', () {
    final samples = allSamples;
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      final s = samples[i % samples.length];
      parse(s.source, s.sender, s.body, receivedAt);
    }
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(10000));
  });
}

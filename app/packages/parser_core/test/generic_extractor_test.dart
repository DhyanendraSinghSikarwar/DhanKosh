// Generic fallback reader for senders no parser claims (FR-38-02, FR-38-03).
// Every message here is synthetic.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

GenericSuggestion? _read(String body, {String sender = 'VM-NEWBNK-S'}) =>
    GenericExtractor.read(sender, body);

void main() {
  group('reads a completed transaction', () {
    test('amount, direction, account, payee and balance score 100', () {
      final s = _read(
        'Rs.1,250.00 debited from A/c XX4821 on 05-11-26 to ZOMATO. '
        'Avl bal Rs.9,400.50',
      )!;
      expect(s.amountMinor, 125000);
      expect(s.currency, 'INR');
      expect(s.type, TransactionType.debit);
      expect(s.last4, '4821');
      expect(s.merchant, isNotNull);
      expect(s.balanceMinor, 940050);
      expect(s.confidence, 100);
      expect(s.showsSuggestion, isTrue);
    });

    test('amount and direction alone score exactly 50 and are not shown', () {
      final s = _read('INR 300 debited.')!;
      expect(s.amountMinor, 30000);
      expect(s.confidence, GenericExtractor.baseConfidence);
      expect(s.showsSuggestion, isFalse);
    });

    test('one corroborating field reaches the threshold', () {
      final s = _read('Rs 80 debited from your account ending 7733.')!;
      expect(s.last4, '7733');
      expect(s.confidence, 70);
      expect(s.showsSuggestion, isTrue);
    });

    test('a credit is income and names the payer', () {
      final s = _read(
        'INR 5,000.00 credited to A/c XX1122 from ASHA DEVI via UPI. '
        'UPI Ref 526812340020',
      )!;
      expect(s.type, TransactionType.credit);
      expect(s.reference, '526812340020');
      expect(s.confidence, greaterThanOrEqualTo(90));
    });

    test('the amount is the first figure that is not a balance or limit', () {
      final s = _read(
        'Avl bal Rs 5,000.00. Rs 450 paid to SWIGGY from a/c XX9090.',
      )!;
      expect(s.amountMinor, 45000);
      expect(s.balanceMinor, 500000);
    });

    test('a foreign currency amount is read in its own currency', () {
      final s = _read('Sent USD 10.00 to TEST CAFE from card ending 1234.')!;
      expect(s.currency, 'USD');
      expect(s.amountMinor, 1000);
      expect(s.balanceMinor, isNull);
    });
  });

  group('rejects what is not a completed money movement', () {
    for (final (why, body) in const [
      (
        'balance only',
        'Your available balance is Rs 12,500.00 as on 05-11-26.'
      ),
      ('declined', 'Transaction of Rs 500 on card ending 1234 was declined.'),
      ('failed', 'Rs 250 payment to ZOMATO failed. Try again.'),
      (
        'OTP with an amount',
        '482910 is your OTP to pay Rs 1,100.00 at ZOMATO.'
      ),
      (
        'a promotion',
        'Pre-approved loan of Rs 5,00,000. Apply now! Get up to 20% off.'
      ),
      (
        'a due reminder',
        'Rs 3,450 is due on 12-11-26 for card ending 5566. Pay now.'
      ),
      (
        'a future debit',
        'Rs 199 will be debited from your account on 10-11-26.'
      ),
      (
        'a money request',
        'ASHA has requested Rs 500 from you. Collect request.'
      ),
      ('no amount', 'Your account was debited. Thank you for banking.'),
      ('no direction', 'Order confirmed for Rs 499. Delivery tomorrow.'),
      (
        'an EMI invitation',
        'Convert your Rs 12,000 purchase into EMI. SmartEMI offer.'
      ),
      ('an e-voucher', 'Rs 500 e-voucher received as a reward.'),
    ]) {
      test(why, () => expect(_read(body), isNull));
    }

    test("a person's phone number is never a bank", () {
      expect(
        GenericExtractor.read(
          '+919876543210',
          'Rs 500 debited from A/c XX1234',
        ),
        isNull,
      );
      expect(GenericExtractor.isPhoneSender('9876543210'), isTrue);
      expect(GenericExtractor.isPhoneSender('VM-HDFCBK'), isFalse);
    });

    test('a very short message is not read', () {
      expect(_read('Rs 5 paid'), isNull);
    });
  });

  group('inbox scan candidates', () {
    test('promotional and government headers are skipped', () {
      const body = 'Rs 500 debited from A/c XX1234';
      expect(GenericExtractor.isCandidate('VM-OFFERS-P', body), isFalse);
      expect(GenericExtractor.isCandidate('AD-GOVTIN-G', body), isFalse);
      expect(GenericExtractor.isCandidate('VM-NEWBNK-S', body), isTrue);
      expect(GenericExtractor.isCandidate('+919876543210', body), isFalse);
    });

    test('a message with no amount is not a candidate', () {
      expect(
        GenericExtractor.isCandidate('VM-NEWBNK-T', 'Your OTP is 123456'),
        isFalse,
      );
    });
  });

  group('a payment app notification with an amount and no direction', () {
    test('read gives nothing, readLoose assumes a payment and says so', () {
      const text = 'Completed: INR 250 to Ravi Kumar via UPI';
      expect(GenericExtractor.read('PhonePe', text), isNull);
      final s = GenericExtractor.readLoose('PhonePe', text)!;
      expect(s.amountMinor, 25000);
      expect(s.type, TransactionType.debit);
      expect(s.directionGuessed, isTrue);
      // A guessed direction starts 10 below the base: 40, plus 20 for the payee.
      expect(s.confidence, 60);
    });

    test('loose reading still rejects OTP, failures and offers', () {
      for (final body in const [
        '482910 is your OTP for Rs 250 payment to Ravi',
        'Payment of Rs 250 to Ravi failed',
        'Get up to Rs 250 cashback! Apply now',
      ]) {
        expect(
          GenericExtractor.readLoose('PhonePe', body),
          isNull,
          reason: body,
        );
      }
    });

    test('a stated direction is never guessed', () {
      final s = GenericExtractor.readLoose(
        'PhonePe',
        'Rs 500 received from Asha Devi',
      )!;
      expect(s.type, TransactionType.credit);
      expect(s.directionGuessed, isFalse);
    });
  });
}

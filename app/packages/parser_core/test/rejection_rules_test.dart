// Port of RejectionRulesTest (FR-06-06, TC-06-06).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

String? reason(String s) =>
    RejectionRules.reasonFor(TextNormalizer.normalize(s));

void main() {
  group('non-transactions are rejected with the right reason', () {
    const rows = [
      ('otp', '482913 is your OTP for txn of Rs 500 at AMAZON on card XX1234'),
      ('otp', 'OTP for online purchase of Rs. 1249.00 at FLIPKART is 482913'),
      ('otp', 'Use OTP 553901 to complete your transaction of INR 1,499.00'),
      ('otp', 'Your one time password is 123456. Do not share.'),
      (
        'failed',
        'Transaction of Rs.500.00 on Card x5678 at FLIPKART has been declined',
      ),
      ('failed', 'Your transaction of Rs 500 failed due to insufficient funds'),
      ('failed', 'Txn of INR 750 was unsuccessful'),
      ('failed', 'Cheque of Rs 5,000 returned unpaid from A/c XX1234'),
      (
        'future',
        'Rs.599.00 will be debited from A/c XX1234 on 01-10-26 towards NETFLIX',
      ),
      ('future', 'Your SIP of INR 1,000 is scheduled for 05-10-26'),
      (
        'mandate',
        'E-mandate for Rs.1,500.00 has been registered successfully on A/c XX1234',
      ),
      ('mandate', 'You have set up an AutoPay for NETFLIX of Rs 649'),
      ('collect', 'RAHUL has requested Rs.500.00 from you on UPI'),
      ('promo', 'Pre-approved personal loan of up to Rs 5 lakh. Apply now'),
      ('promo', 'Congratulations! You are eligible for a credit card'),
      (
        'reminder',
        'Total Amt Due Rs.12,345.00 Min Amt Due Rs.620.00 due by 05-10-26',
      ),
      (
        'reminder',
        'Your statement for September 2026 is ready. Total Amount Due INR 8,000',
      ),
    ];
    for (final (expected, text) in rows) {
      test(text, () => expect(reason(text), expected));
    }
  });

  group('real transactions survive', () {
    for (final text in [
      'Rs.250.00 debited from A/c XX1234 on 25-09-26. Never share your OTP with anyone.',
      'INR 1,499.00 spent on Card XX9012 at AMAZON. SMS BLOCK 9012 to 5676766. Do not share OTP.',
      'INR 500.00 credited to A/c XX1234 as reversal of failed txn on 20-09-26',
      'Payment of INR 5,000 received towards your Credit Card XX9012. Total due now INR 1,000',
      'INR 199.00 debited via UPI AutoPay for NETFLIX from A/c XX1234. RRN 525912345678',
    ]) {
      test(text, () => expect(reason(text), isNull));
    }
  });

  test('a balance-only note is rejected unless money moved', () {
    expect(
      reason(
        'Your available balance in account ending XX5152 is Rs. 1,155.70 as '
        'on 17-OCT-25',
      ),
      'balance',
    );
  });
}

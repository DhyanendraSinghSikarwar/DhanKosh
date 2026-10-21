// Messages end to end, as the app reads them: SMS and email through the
// registry. Asserts the transaction that would be stored: amount, type,
// account, category, balance. Port of SmsToTransactionTest (FR-06-05,
// FR-06-12). The Kotlin statement-row test belongs to the statements feature
// (Phase 3) and is not ported.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

void main() {
  final registry = ParserRegistry.standard();
  ParsedTransaction? sms(String sender, String body) =>
      registry.parse(body, sender, receivedAt, Source.sms);

  test(
      'UPI debit with balance is a spend on the account and states its '
      'balance', () {
    final tx = sms(
      'VM-HDFCBK',
      'UPDATE: INR 1,240.00 debited from HDFC Bank XX2779 on 24-SEP-26. '
          'Info: UPI-SWIGGY-swiggy@icici. Avl bal:INR 23,410.00',
    )!;
    expect(tx.amountMinor, 124000);
    expect(tx.type, TransactionType.debit);
    expect(tx.bankName, 'HDFC Bank');
    expect(tx.accountLast4, '2779');
    expect(tx.accountKind, AccountKind.account);
    expect(tx.category, Category.food);
    expect(tx.balanceMinor, 2341000);
  });

  test('salary credit is income on the account', () {
    final tx = sms(
      'VM-HDFCBK',
      'Update! INR 85,000.00 deposited in HDFC Bank A/c XX2779 on 01-SEP-26 '
          'for NEFT Cr-CITI0000001-ACME CORP SALARY-XXXXXX-CITIN52026090112345. '
          'Avl bal INR 1,08,410.00.',
    )!;
    expect(tx.amountMinor, 8500000);
    expect(tx.type, TransactionType.credit);
    expect(tx.accountLast4, '2779');
    expect(tx.balanceMinor, 10841000);
  });

  test('credit card spend states the available limit, not a balance', () {
    final tx = sms(
      'VM-HDFCBK',
      'Rs.349.00 spent via HDFC Bank Card xx5678 at UBER INDIA on '
          '2026-09-20:22:01:45 Avl Lmt: Rs 1,23,456.00',
    )!;
    expect(tx.amountMinor, 34900);
    expect(tx.accountKind, AccountKind.card);
    expect(tx.accountLast4, '5678');
    expect(tx.category, Category.transport);
    expect(tx.availableLimitMinor, 12345600);
    expect(tx.balanceMinor, isNull);
  });

  test('SIP debit is an investment, not a spend', () {
    final tx = sms(
      'VM-HDFCBK',
      'UPDATE: INR 5,000.00 debited from HDFC Bank XX2779 on 05-SEP-26. '
          'Info: ACH D- TP ACH ZERODHA-1234567. Avl bal:INR 23,410.00',
    )!;
    expect(tx.type, TransactionType.investment);
    expect(tx.amountMinor, 500000);
  });

  test('card bill payment is a transfer', () {
    final tx = sms(
      'VM-HDFCBK',
      'Payment of Rs 12,345.00 received towards your HDFC Bank Credit Card '
          'XX5678 on 18-09-26.',
    )!;
    expect(tx.type, TransactionType.transfer);
    expect(tx.accountKind, AccountKind.card);
  });

  test('OTPs, offers and declines are not transactions', () {
    expect(
      sms(
        'VM-HDFCBK',
        '123456 is your OTP for txn of INR 1,500.00 at AMAZON on HDFC Bank '
            'card ending 5678. Valid for 5 mins.',
      ),
      isNull,
    );
    expect(
      sms(
        'VM-HDFCBK',
        'Get a Personal Loan of up to Rs.40 lakh, pre-approved for you! '
            'Apply now: hdfcbk.io/x7Yt',
      ),
      isNull,
    );
    expect(
      sms(
        'VM-HDFCBK',
        'Transaction of Rs.500.00 on HDFC Bank Card x5678 at FLIPKART has '
            'been declined due to insufficient balance.',
      ),
      isNull,
    );
  });

  test('bank alert email is the same transaction as its SMS', () {
    final email = registry.parse(
      'Dear Customer,\n\nRs.450.00 has been debited from account **2779 to '
          'VPA swiggy@icici SWIGGY on 24-09-26.\n\n'
          'Your UPI transaction reference number is 526812345678.\n\n'
          'Warm Regards,\nHDFC Bank',
      'HDFC Bank InstaAlerts <alerts@hdfcbank.net>',
      receivedAt,
      Source.email,
    )!;
    final text = registry.parse(
      'Sent Rs.450.00\nFrom HDFC Bank A/C *2779\nTo SWIGGY\nOn 24/09/26\n'
          'Ref 526812345678\nNot You?\n'
          'Call 18002586161/SMS BLOCK UPI to 7308080808',
      'VM-HDFCBK',
      receivedAt,
      Source.sms,
    )!;
    expect(email.amountMinor, text.amountMinor);
    expect(email.accountLast4, text.accountLast4);
    expect(email.referenceNumber, text.referenceNumber);
    expect(email.transactionHash, text.transactionHash);
  });
}

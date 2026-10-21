// Real messages from user feedback (numbers changed), and the free-text paths
// for screenshots and app notifications. Port of FeedbackCasesTest (FR-06-07,
// FR-06-10, FR-06-12, FR-06-16).
// Long messages are written as adjacent literals so each fixture reads as
// one message.
// ignore_for_file: no_adjacent_strings_in_list

import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

void main() {
  final registry = ParserRegistry.standard();
  const free = FreeTextParser();

  test(
      'card number with only two digits is still a card spend, in its own '
      'currency', () {
    final tx = registry.parse(
      'USD200.00 was spent on your SBI Corporate Card number ending with 96 '
          'at ANTHROPIC on 01/10/26. Available Credit Limit: Rs.59,165.07, '
          "If this trxn. wasn't done by you, call 18605003000",
      'VM-SBICRD-S',
      receivedAt,
      Source.sms,
    );
    expect(tx, isNotNull);
    expect(tx!.amountMinor, 20000); // the USD amount, not the limit
    expect(tx.currency, 'USD');
    expect(tx.type, TransactionType.debit);
    expect(tx.accountLast4, '96');
    expect(tx.accountKind, AccountKind.card);
    expect(tx.availableLimitMinor, 5916507);
  });

  test(
      'debit card withdrawal is cash, keeps the account balance, and is '
      'marked as a debit card', () {
    final tx = registry.parse(
      'Withdrawn Rs.10000 From HDFC Bank Card x2139 At +NALLAGANDLA 3 On '
          '2026-09-20:14:20:34 Bal Rs.573096.22 '
          'Not You? Call 18002586161/SMS BLOCK DC 2139 to 7308080808',
      'AD-HDFCBK-S',
      receivedAt,
      Source.sms,
    );
    expect(tx, isNotNull);
    expect(tx!.amountMinor, 1000000);
    expect(tx.accountKind, AccountKind.card);
    expect(tx.isDebitCard, isTrue);
    expect(tx.channel, Channel.atm);
    expect(tx.category, Category.cash);
    expect(tx.balanceMinor, 57309622);
  });

  test('credit card spends are not marked as debit cards', () {
    final tx = registry.parse(
      'Rs.349.00 spent via HDFC Bank Card xx5678 at UBER INDIA on '
          '2026-09-20:22:01:45 Avl Lmt: Rs 1,23,456.00',
      'VM-HDFCBK',
      receivedAt,
      Source.sms,
    )!;
    expect(tx.isDebitCard, isFalse);
    expect(tx.balanceMinor, isNull);
  });

  test('paying a card bill from the bank is a transfer, not spending', () {
    for (final body in [
      'Rs 12,345.00 debited from A/c XX1234 on 05-09-26 towards your HDFC '
          'Bank Credit Card XX5678. Avl Bal Rs 40,000.00',
      'INR 8,000.00 debited from A/c XX1234 for CC bill payment on 05-09-26. '
          'Ref 526812341111',
    ]) {
      final tx = registry.parse(body, 'VM-HDFCBK', receivedAt, Source.sms);
      expect(tx!.type, TransactionType.transfer, reason: body);
    }
  });

  test('insurers are recognised as insurance', () {
    final tx = registry.parse(
      'Rs 18,500.00 debited from A/c XX1234 on 05-09-26 to STAR HEALTH AND '
          'ALLIED INSURANCE. Ref 526812342222',
      'VM-HDFCBK',
      receivedAt,
      Source.sms,
    );
    expect(tx!.category, Category.insurance);
  });

  test('payment app notifications become transactions', () {
    final paid = free.fromNotification(
      'Google Pay',
      '₹250 paid to Swiggy',
      'Payment successful',
      receivedAt,
    );
    expect(paid, isNotNull);
    expect(paid!.amountMinor, 25000);
    expect(paid.type, TransactionType.debit);
    expect(paid.source, Source.app);

    final got = free.fromNotification(
      'PhonePe',
      'Received ₹1,200 from Asha Verma',
      null,
      receivedAt,
    );
    expect(got!.type, TransactionType.credit);
    expect(got.amountMinor, 120000);
  });

  test('offers, requests and reminders from payment apps are ignored', () {
    for (final text in [
      "You've won ₹50 cashback! Scratch your card now",
      'Raju has requested ₹500 from you. Pay now',
      'Your electricity bill of ₹1,240 is due tomorrow. Pay now',
      'Payment of ₹300 to Zomato failed. Money will be refunded',
      '123456 is your OTP to pay ₹500',
    ]) {
      expect(
        free.fromNotification('App', text, null, receivedAt),
        isNull,
        reason: text,
      );
    }
  });

  test(
      'a payment screenshot gives a draft with amount, merchant and '
      'reference', () {
    const ocr = 'Paid to\nSWIGGY\n₹ 456\nCompleted\n25 Sep 2026, 10:12 am\n'
        'UPI transaction ID\n526812349999\nTo: SWIGGY\nswiggy@icici\n'
        'From: HDFC Bank 1234';
    final d = free.draft(ocr, receivedAt);
    expect(d, isNotNull);
    expect(d!.amountMinor, 45600);
    expect(d.type, TransactionType.debit);
    expect(d.reference, '526812349999');
    expect(d.bankName, 'HDFC Bank');
  });

  test('a balance-only email is not a credit', () {
    const body =
        'Dear Customer, Greetings from HDFC Bank! Your available balance in '
        'account ending XX5152 is Rs. INR 1,155.70 as on 17-OCT-25 Your '
        'account is maintained at HDFC Bank, KOYALI. If you ve deposited a '
        'cheque, the amount will reflect after clearance. For real-time '
        'balance updates, you can call us at 1800 270 3333.';
    expect(
      registry.parse(body, 'alerts@hdfcbank.net', receivedAt, Source.email),
      isNull,
    );
  });

  test('a merchant name glued to a terminal id is recognised', () {
    final tx = registry.parse(
      'Spent Rs.276.53 On HDFC Bank Card 2779 At UBERIND13513699 On '
          '2026-10-01:18:24:32.Not You? '
          'To Block+Reissue Call 18002586161/SMS BLOCK CC 2779 to 7308080808',
      'VM-HDFCBK',
      receivedAt,
      Source.sms,
    )!;
    expect(tx.merchant, 'Uber');
    expect(tx.category, Category.transport);
    expect(tx.accountLast4, '2779');
  });

  test("the payee's account is never taken as the user's", () {
    final tx = registry.parse(
      'Rs.5,000.00 transferred to A/c XX9876 from your A/c XX1234 on 05-09-26 '
          'via IMPS. Ref 526812345678',
      'VM-HDFCBK',
      receivedAt,
      Source.sms,
    )!;
    expect(tx.accountLast4, '1234');
    final onlyPayee = registry.parse(
      'Rs.5,000.00 sent to A/c XX9876 on 05-09-26 via IMPS. Ref 526812345679',
      'VM-HDFCBK',
      receivedAt,
      Source.sms,
    );
    expect(onlyPayee?.accountLast4, isNull);
  });

  test('ui phrases from notifications never become a merchant', () {
    for (final phrase in [
      'View Details',
      'Know more',
      'Check balance',
      'Tap to view',
      'Download',
      'Learn more',
      'Track order',
      'Explore',
      'Open app',
    ]) {
      final got = free.fromNotification(
        'Google Pay',
        'Payment successful',
        '₹144 paid. $phrase',
        receivedAt,
      );
      expect(got, isNotNull, reason: phrase);
      expect(got!.merchant, isNull, reason: phrase);
    }
    final real = free.fromNotification(
      'Google Pay',
      '₹250 paid to Swiggy',
      'View Details',
      receivedAt,
    );
    expect(real!.merchant, 'Swiggy');
  });

  test('listed Indian banks are recognised by their sender code', () {
    const cases = {
      'VM-NSBANK-S': 'Nagrik Sahakari Bank',
      'AX-CENTBK-S': 'Central Bank of India',
      'VK-MAHABK-S': 'Bank of Maharashtra',
      'AD-CANBNK-S': 'Canara Bank',
      'JD-UNIONB-S': 'Union Bank of India',
      'TM-BOIIND-S': 'Bank of India',
      'AX-FEDBNK-S': 'Federal Bank',
      'VM-SIBSMS-S': 'South Indian Bank',
      'BP-JKBANK-S': 'Jammu & Kashmir Bank',
      'AD-SARBNK-S': 'Saraswat Bank',
      'VK-PYTMPB-S': 'Paytm Payments Bank',
      'VM-UCOBNK-S': 'UCO Bank',
    };
    cases.forEach((sender, bank) {
      final tx = registry.parse(
        'Dear Customer, A/c XXXXXX4821 is debited by Rs.1,250.00 on '
        '05-10-2026 via UPI/527812345678. Avl Bal Rs.18,340.50',
        sender,
        receivedAt,
        Source.sms,
      );
      expect(tx, isNotNull, reason: sender);
      expect(tx!.bankName, bank, reason: sender);
      expect(tx.type, TransactionType.debit, reason: sender);
      expect(tx.amountMinor, 125000, reason: sender);
      expect(tx.accountLast4, '4821', reason: sender);
    });
  });

  test('no two banks claim one sender code', () {
    final keys = [for (final p in registry.parsers) ...p.senderKeys];
    expect(keys.length, keys.toSet().length);
  });

  test('axis card spend in the newer multi-line layout', () {
    final tx = registry.parse(
      'Spent INR 1234.56\nAxis Bank Card no. XX4821\n07-10-26 23:16:18 IST\n'
          'Croma Retail\nAvl Limit: INR 185432.10\n'
          'Not you? SMS BLOCK 4821 to 919951860002',
      'VK-AXISBK-S',
      receivedAt,
      Source.sms,
    );
    expect(tx, isNotNull);
    expect(tx!.bankName, 'Axis Bank');
    expect(tx.type, TransactionType.debit);
    expect(tx.amountMinor, 123456);
    expect(tx.accountLast4, '4821');
    expect(tx.accountKind, AccountKind.card);
    expect(tx.merchant, 'Croma');
    expect(tx.availableLimitMinor, 18543210);
  });
}

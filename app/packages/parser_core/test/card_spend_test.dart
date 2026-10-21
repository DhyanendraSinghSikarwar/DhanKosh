// Online credit-card spends (a purchase on a laptop, confirmed with an OTP).
// The OTP SMS itself must be rejected; the spend alert that follows must be
// counted, including from issuers with no dedicated parser. Port of
// CardSpendTest (FR-06-04, FR-06-12).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

class _Spend {
  const _Spend(
    this.sender,
    this.body,
    this.amountMinor,
    this.last4, [
    this.currency = 'INR',
  ]);

  final String sender;
  final String body;
  final int amountMinor;
  final String last4;
  final String currency;
}

const _spends = [
  _Spend(
    'JD-HDFCBK-S',
    'Spent Rs.2,499.00 On HDFC Bank Card 5678 At RAZ*AMAZON On '
        '2026-09-24:21:14:05 Not You? To Block+Reissue Call '
        '18002586161/SMS BLOCK CC 5678 to 7308080808',
    249900,
    '5678',
  ),
  _Spend(
    'VM-HDFCBK',
    'Txn Rs.1,250.00\nOn HDFC Bank Card 5678\nAt MAKEMYTRIP\nby UPI '
        '626712345678\nOn 24-09\nNot You?\nCall 18002586161/SMS BLOCK CC 5678 '
        'to 7308080808',
    125000,
    '5678',
  ),
  _Spend(
    'AX-ICICIB',
    'INR 3,200.00 spent using ICICI Bank Card XX9012 on 24-Sep-26 on '
        'IND*Amazon. Avl Limit: INR 96,800.00. If not you, call 1800 '
        '2662/SMS BLOCK 9012 to 9215676766.',
    320000,
    '9012',
  ),
  _Spend(
    'AD-SBICRD',
    'Rs.1,799.00 spent on your SBI Credit Card ending with 3456 at FLIPKART '
        'on 24/09/26. Trxn. not done by you? Report at '
        'https://sbicard.com/Dispute',
    179900,
    '3456',
  ),
  _Spend(
    'VM-AXISBK',
    'Spent\nCard no. XX7890\nINR 4500\n24-09-26 20:11:05 IST\nAMAZON PAY '
        'IN\nAvl Lmt INR 95500\nSMS BLOCK 7890 to 919951860002, if not you - '
        'Axis Bank',
    450000,
    '7890',
  ),
  _Spend(
    'VM-KOTAKB',
    'Transaction of Rs.899.00 on Kotak Credit Card xx2345 at SWIGGY on '
        '24/09/2026. Avl limit Rs.45,000. Not you? Call 18602662666',
    89900,
    '2345',
  ),
  _Spend(
    'BZ-INDUSB',
    'Your IndusInd Bank Credit Card ending 6789 has been used for INR '
        '1,100.00 at ZOMATO on 24/09/26 at 21:30. Avl limit INR 1,98,900. If '
        'not done by you, call 18602677777',
    110000,
    '6789',
  ),
  _Spend(
    'AD-AMEXIN',
    "Alert: You've spent INR 2,345.00 on your AMEX card ** 41005 at AMAZON "
        'on 24 September 2026 at 09:10 PM IST. Call 18004190691 if this was '
        'not made by you.',
    234500,
    '1005',
  ),
  _Spend(
    'VM-RBLCRD',
    'Dear Customer, you have made a transaction of INR 1,500.00 at AMAZON on '
        'your RBL Bank Credit Card XX1122 on 24-09-2026.',
    150000,
    '1122',
  ),
  _Spend(
    'VM-HSBCIN',
    'Your HSBC credit card ending with 3344 has been used for INR 5,000.00 at '
        'MAKEMYTRIP on 24SEP26 at 14:22.',
    500000,
    '3344',
  ),
  _Spend(
    'AD-SCBANK',
    'Txn of INR 1,299.00 done on your StanChart Credit Card no. XX5566 at '
        'AMAZON on 24/09/26.',
    129900,
    '5566',
  ),
  _Spend(
    'VM-IDFCFB',
    'INR 750.00 spent on your IDFC FIRST Bank Credit Card ending XX7788 at '
        'SWIGGY on 24-SEP-2026 at 13:20. Avl Limit: INR 99,250.00',
    75000,
    '7788',
  ),
  _Spend(
    'JM-ONECRD',
    'Rs. 599 spent at NETFLIX on your OneCard ending 4321. Available limit: '
        'Rs. 49,401.',
    59900,
    '4321',
  ),
  _Spend(
    'VM-HDFCBK',
    'USD 12.99 spent on HDFC Bank Card x5678 at OPENAI *CHATGPT on '
        '2026-09-24:10:00:00. Not You? Call 18002586161',
    1299,
    '5678',
    'USD',
  ),
];

const _otps = [
  (
    'JD-HDFCBK-S',
    'OTP is 482910 for transaction of INR 2,499.00 at AMAZON on HDFC Bank '
        'Card 5678. Valid for 10 mins. Do not share.',
  ),
  (
    'BZ-INDUSB',
    'Your OTP to complete the purchase of INR 1,100.00 at ZOMATO with '
        'IndusInd Credit Card XX6789 is 482910. Do not share it with anyone.',
  ),
  (
    'VM-IDFCFB',
    '482910 is the OTP for your transaction of INR 750.00 at SWIGGY on IDFC '
        'FIRST Bank Credit Card XX7788. Valid for 3 minutes.',
  ),
  (
    'VM-HSBCIN',
    'Transaction of INR 5,000.00 at MAKEMYTRIP on your HSBC credit card '
        'ending 3344 was declined.',
  ),
  (
    'AD-AMEXIN',
    'Use 482910 as the one time password to authenticate the transaction of '
        'INR 2,345.00 at AMAZON on your AMEX card ** 41005.',
  ),
];

void main() {
  final registry = ParserRegistry.standard();

  group('online card spend is counted', () {
    for (final s in _spends) {
      test('${s.sender}: ${s.body.substring(0, 40).replaceAll('\n', ' ')}', () {
        expect(registry.accepts(s.sender), isTrue, reason: 'pre-filter drops');
        final tx = registry.parse(s.body, s.sender, receivedAt, Source.sms);
        expect(tx, isNotNull, reason: s.body);
        expect(tx!.type, TransactionType.debit, reason: s.body);
        expect(tx.amountMinor, s.amountMinor, reason: s.body);
        expect(tx.accountLast4, s.last4, reason: s.body);
        expect(tx.accountKind, AccountKind.card, reason: s.body);
        expect(tx.currency, s.currency, reason: s.body);
      });
    }
  });

  group('otp and declined attempts are not counted', () {
    for (final (sender, body) in _otps) {
      test(body.substring(0, 40), () {
        expect(
          registry.parse(body, sender, receivedAt, Source.sms),
          isNull,
          reason: body,
        );
      });
    }
  });

  test('pre-filter still skips senders that are not banks', () {
    for (final s in [
      'VM-AMAZON',
      'AD-SWIGGY',
      '+919876543210',
      'JD-FLPKRT',
      'VK-ZOMATO',
    ]) {
      expect(registry.accepts(s), isFalse, reason: s);
    }
  });
}

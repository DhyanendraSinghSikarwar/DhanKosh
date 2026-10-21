// Card dues as issuers print them in statements, and as they announce them by
// SMS or email. Port of CardDuesTest (FR-05-06, FR-05-08, TC-05-06, TC-05-08).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';
import 'support/statement_support.dart';

void main() {
  const parser = StatementParser();
  final at = receivedAt;
  final registry = ParserRegistry.standard();

  void check(
    String text,
    String sender,
    String bank,
    String last4,
    int total,
    int? min,
    CivilDate due,
    CivilDate stmt, [
    int? limit,
  ]) {
    final r = parser.parse(dedent(text), sender, at);
    expect(r.statementKind, StatementKind.creditCard, reason: bank);
    expect(r.bankName, bank);
    expect(r.last4, last4, reason: bank);
    expect(r.summary.totalDueMinor, total, reason: '$bank total');
    expect(r.summary.minDueMinor, min, reason: '$bank min');
    expect(r.summary.dueDate, due, reason: '$bank due date');
    expect(r.summary.statementDate, stmt, reason: '$bank statement date');
    if (limit != null) {
      expect(r.summary.creditLimitMinor, limit, reason: '$bank limit');
    }
  }

  int day(int y, int m, int d) => CivilDate(y, m, d).toEpochDay();

  test('HDFC header row then values row with rupee glyph and cash limit column',
      () {
    check(
      r'''
      HDFC Bank Credit Cards Statement
      Name: A SHARMA
      Card No: 4000 00XX XXXX 5521
      Statement Date:20/09/2026
      Payment Due Date Total Dues Minimum Amount Due
      21/10/2026 C12,345.00 C620.00
      Credit Limit Available Credit Limit Available Cash Limit
      C2,00,000.00 C1,75,000.00 C40,000.00
      ''',
      'HDFC Bank <emailstatements.cards@hdfcbank.net>',
      'HDFC Bank',
      '5521',
      1234500,
      62000,
      const CivilDate(2026, 10, 21),
      const CivilDate(2026, 9, 20),
      20000000,
    );
  });

  test('HDFC available limit is not taken for the credit limit', () {
    final r = parser.parse(
      'HDFC Bank Credit Card Statement\nCard No: 4000 00XX XXXX 5521\n'
          'Credit Limit Available Credit Limit Available Cash Limit\n'
          'C2,00,000.00 C1,75,000.00 C40,000.00',
      'HDFC Bank <x@hdfcbank.net>',
      at,
    );
    expect(r.summary.creditLimitMinor, 20000000);
    expect(r.summary.availableMinor, 17500000);
  });

  test('ICICI one label per line with the value on the next line and a Dr', () {
    check(
      r'''
      ICICI Bank Credit Card Statement
      Credit Card No: 4375 XXXX XXXX 8842
      STATEMENT DATE
      20-Sep-2026
      PAYMENT DUE DATE
      08-Oct-2026
      Total Amount due
      Rs.24,560.75 Dr
      Minimum Amount due
      Rs.1,230.00
      Credit Limit
      Rs.2,00,000.00
      Available Credit Limit
      Rs.1,75,439.25
      ''',
      'ICICI Bank <credit_cards@icicibank.com>',
      'ICICI Bank',
      '8842',
      2456075,
      123000,
      const CivilDate(2026, 10, 8),
      const CivilDate(2026, 9, 20),
      20000000,
    );
  });

  test('SBI Card label block then value block', () {
    check(
      r'''
      SBI Card
      Credit Card Statement
      SBI Card ending XXXX XXXX XXXX 7310
      Statement Date
      Payment Due Date
      Total Amount Due
      Minimum Amount Due
      12 Oct 2026
      02 Nov 2026
      ₹5,430.00
      ₹270.00
      ''',
      'SBI Card <Statements@sbicard.com>',
      'SBI',
      '7310',
      543000,
      27000,
      const CivilDate(2026, 11, 2),
      const CivilDate(2026, 10, 12),
    );
  });

  test('Axis total payment due with Dr and statement period', () {
    check(
      r'''
      Axis Bank Credit Card Statement
      Card No: 4147XXXXXXXX3190
      Statement Period: 13/08/2026 To 12/09/2026
      Statement Generation Date 12/09/2026
      Payment Summary
      Total Payment Due Minimum Payment Due Payment Due Date
      Rs. 8,100.00 Dr Rs. 405.00 Dr 02/10/2026
      Credit Limit Available Credit Limit
      Rs. 1,50,000.00 Rs. 1,41,900.00
      ''',
      'Axis Bank <cc.statements@axisbank.com>',
      'Axis Bank',
      '3190',
      810000,
      40500,
      const CivilDate(2026, 10, 2),
      const CivilDate(2026, 9, 12),
      15000000,
    );
  });

  test('Axis statement period gives the statement date when none is printed',
      () {
    final r = parser.parse(
      'Axis Bank Credit Card Statement\nCard No: 4147XXXXXXXX3190\n'
          'Statement Period: 13/08/2026 To 12/09/2026\nTotal Payment Due Rs. 100.00',
      'Axis Bank <cc@axisbank.com>',
      at,
    );
    expect(r.summary.statementDate, const CivilDate(2026, 9, 12));
  });

  test('Kotak labels with colons on one line each', () {
    check(
      r'''
      Kotak Mahindra Bank Credit Card Statement
      Card Number: 5241 80XX XXXX 7788
      Statement Date: 15-Sep-2026
      Total Amount Due: Rs. 18,250.40
      Minimum Amount Due: Rs. 912.52
      Payment Due Date: 05-Oct-2026
      Credit Limit: Rs. 3,00,000.00
      ''',
      'Kotak <statements@kotak.com>',
      'Kotak Mahindra Bank',
      '7788',
      1825040,
      91252,
      const CivilDate(2026, 10, 5),
      const CivilDate(2026, 9, 15),
      30000000,
    );
  });

  test('IDFC FIRST rupee sign and dd-mm-yyyy', () {
    check(
      r'''
      IDFC FIRST Bank Credit Card Statement
      Card Number XXXX XXXX XXXX 3321
      Statement Date 11/09/2026
      Payment Due Date 29/09/2026
      Total Amount Due ₹ 12,480.00
      Minimum Amount Due ₹ 624.00
      Credit Limit ₹ 1,00,000.00
      ''',
      'IDFC FIRST Bank <cards@idfcfirstbank.com>',
      'IDFC FIRST Bank',
      '3321',
      1248000,
      62400,
      const CivilDate(2026, 9, 29),
      const CivilDate(2026, 9, 11),
      10000000,
    );
  });

  test('Yes Bank due date without a year and INR amounts', () {
    check(
      r'''
      YES BANK Credit Card Statement
      Card Number: 4580 XXXX XXXX 9145
      Statement Date 10 Sep 2026
      Payment Due Date 30 September
      Total Amount Due INR 6,750.00
      Minimum Amount Due INR 340.00
      Credit Limit INR 75,000.00
      ''',
      'YES BANK <estatement@yesbank.in>',
      'Yes Bank',
      '9145',
      675000,
      34000,
      const CivilDate(2026, 9, 30),
      const CivilDate(2026, 9, 10),
      7500000,
    );
  });

  test('AU total payment due', () {
    check(
      r'''
      AU Small Finance Bank Credit Card Statement
      Card No: XXXX XXXX XXXX 6110
      Statement Date : 18/09/2026
      Total Payment Due : Rs 9,999.00
      Minimum Payment Due : Rs 500.00
      Payment Due Date : 08/10/2026
      Credit Limit : Rs 1,20,000.00
      ''',
      'AU Bank <cards@aubank.in>',
      'AU Small Finance Bank',
      '6110',
      999900,
      50000,
      const CivilDate(2026, 10, 8),
      const CivilDate(2026, 9, 18),
      12000000,
    );
  });

  test('RBL two header rows each followed by a values row', () {
    check(
      r'''
      RBL Bank Credit Card Statement
      Card No. 5236 XXXX XXXX 1450
      Statement Date Payment Due Date
      14-09-2026 04-10-2026
      Total Amount Due Minimum Amount Due
      ₹ 31,200.00 ₹ 1,560.00
      Credit Limit Available Credit Limit
      ₹ 2,50,000.00 ₹ 2,18,800.00
      ''',
      'RBL Bank <cards@rblbank.com>',
      'RBL Bank',
      '1450',
      3120000,
      156000,
      const CivilDate(2026, 10, 4),
      const CivilDate(2026, 9, 14),
      25000000,
    );
  });

  test('IndusInd amounts with a trailing Dr', () {
    check(
      r'''
      IndusInd Bank Credit Card Statement
      Card Number XXXX XXXX XXXX 8802
      Statement Date 05/09/2026
      Total Amount Due 4,321.50 Dr
      Minimum Amount Due 216.00 Dr
      Payment Due Date 25/09/2026
      Credit Limit 90,000.00
      ''',
      'IndusInd Bank <cards@indusind.com>',
      'IndusInd Bank',
      '8802',
      432150,
      21600,
      const CivilDate(2026, 9, 25),
      const CivilDate(2026, 9, 5),
      9000000,
    );
  });

  test('American Express new balance and minimum payment due', () {
    check(
      r'''
      American Express Credit Card Statement
      Card Number: XXXX-XXXXXX-1007
      Statement Closing Date 10 Sep 2026
      New Balance Rs. 45,210.00
      Minimum Payment Due Rs. 2,260.00
      Payment Due Date 05 Oct 2026
      ''',
      'American Express <AmericanExpress@welcome.americanexpress.com>',
      'American Express',
      '1007',
      4521000,
      226000,
      const CivilDate(2026, 10, 5),
      const CivilDate(2026, 9, 10),
    );
  });

  test('HSBC and Standard Chartered', () {
    check(
      r'''
      HSBC Credit Card Statement
      Card Number 4546 XXXX XXXX 3099
      Statement Date 22 Sep 2026
      Payment Due Date 12 Oct 2026
      Total Amount Due Rs 15,000.00
      Minimum Amount Due Rs 750.00
      Credit Limit Rs 2,50,000.00
      ''',
      'HSBC <hsbc@mail.hsbc.co.in>',
      'HSBC',
      '3099',
      1500000,
      75000,
      const CivilDate(2026, 10, 12),
      const CivilDate(2026, 9, 22),
      25000000,
    );
    check(
      r'''
      Standard Chartered Bank Credit Card Statement
      Card No XXXX XXXX XXXX 6677
      Statement Date 21-09-2026
      Total Amount Due 7,800.00
      Minimum Amount Due 390.00
      Payment Due Date 11-10-2026
      ''',
      'Standard Chartered <statements@sc.com>',
      'Standard Chartered',
      '6677',
      780000,
      39000,
      const CivilDate(2026, 10, 11),
      const CivilDate(2026, 9, 21),
    );
  });

  test('Federal OneCard short labels', () {
    check(
      r'''
      OneCard Federal Bank Credit Card Statement
      Card Number XXXX XXXX XXXX 2024
      Statement Date 01/09/2026
      Total Due ₹ 22,000.00
      Minimum Due ₹ 1,100.00
      Due Date 21/09/2026
      ''',
      'OneCard <statements@getonecard.app>',
      'Federal Bank',
      '2024',
      2200000,
      110000,
      const CivilDate(2026, 9, 21),
      const CivilDate(2026, 9, 1),
    );
  });

  test('two digit year and a credit balance', () {
    final r = parser.parse(
      'Axis Bank Credit Card Statement\nCard No XXXX XXXX XXXX 1111\n'
          'Statement Date 12/09/26\nTotal Amount Due 1,200.00 Cr\n'
          'Payment Due Date 02/10/26',
      'Axis Bank <cc@axisbank.com>',
      at,
    );
    expect(r.summary.totalDueMinor, 0);
    expect(r.summary.dueDate, const CivilDate(2026, 10, 2));
    expect(r.summary.statementDate, const CivilDate(2026, 9, 12));
  });

  // SMS and email messages.

  test('HDFC statement SMS', () {
    final d = registry.cardDue(
      'Your HDFC Bank Credit Card XX5521 statement is generated. Total Amount '
          'Due Rs.12,345.00, Minimum Amount Due Rs.620.00, Payment Due Date '
          '21-OCT-2026',
      'VM-HDFCBK',
      at,
    );
    expect(d, isNotNull);
    expect(d!.bank, 'HDFC Bank');
    expect(d.last4, '5521');
    expect(d.totalDueMinor, 1234500);
    expect(d.minDueMinor, 62000);
    expect(d.dueEpochDay, day(2026, 10, 21));
  });

  test('SBI Card statement SMS with two digit years', () {
    final d = registry.cardDue(
      'SBI Card ending 7310: Statement dated 12/10/26. Total amt due Rs 5,430, '
          'min amt due Rs 270, pay by 02/11/26',
      'VM-SBICRD',
      at,
    );
    expect(d, isNotNull);
    expect(d!.bank, 'SBI');
    expect(d.last4, '7310');
    expect(d.totalDueMinor, 543000);
    expect(d.minDueMinor, 27000);
    expect(d.dueEpochDay, day(2026, 11, 2));
    expect(d.statementEpochDay, day(2026, 10, 12));
  });

  test('ICICI statement SMS', () {
    final d = CardDueParser.parse(
      'ICICI Bank Credit Card XX8842 statement dated 20-SEP-2026 is generated. '
          'Total Amount due: INR 24,560.75. Minimum due: INR 1,230.00. Please pay '
          'by 08-OCT-2026.',
      'ICICI Bank',
      at,
    );
    expect(d, isNotNull);
    expect(d!.totalDueMinor, 2456075);
    expect(d.minDueMinor, 123000);
    expect(d.dueEpochDay, day(2026, 10, 8));
    expect(d.statementEpochDay, day(2026, 9, 20));
  });

  test('Axis statement SMS', () {
    final d = registry.cardDue(
      'Axis Bank Credit Card No. XX3190: Total payment due INR 8,100.00. '
          'Minimum payment due INR 405.00. Due date 02-10-2026.',
      'AX-AXISBK',
      at,
    );
    expect(d, isNotNull);
    expect(d!.bank, 'Axis Bank');
    expect(d.last4, '3190');
    expect(d.totalDueMinor, 810000);
    expect(d.minDueMinor, 40500);
    expect(d.dueEpochDay, day(2026, 10, 2));
  });

  test('payment acknowledgement', () {
    final d = registry.cardDue(
      'Payment of Rs.12,345.00 has been received towards your HDFC Bank Credit '
          'Card XX5521 on 05-OCT-2026. Thank you.',
      'VM-HDFCBK',
      at,
    );
    expect(d, isNotNull);
    expect(d!.paymentMinor, 1234500);
    expect(d.totalDueMinor, isNull);
  });

  test('card spend alerts and failed payments are not dues', () {
    expect(
      registry.cardDue(
        'Spent Rs.276.53 On HDFC Bank Card 5521 At SWIGGY On '
            '2026-09-24:10:12:11. Avl Lmt Rs.1,23,456.00',
        'VM-HDFCBK',
        at,
      ),
      isNull,
    );
    expect(
      registry.cardDue(
        'Payment of Rs.5,000.00 towards your HDFC Bank Credit Card XX5521 '
            'failed.',
        'VM-HDFCBK',
        at,
      ),
      isNull,
    );
    expect(
      registry.cardDue(
        'Your A/c XX1234 balance is Rs 1,000.00. Minimum balance Rs 500.',
        'VM-HDFCBK',
        at,
      ),
      isNull,
    );
  });

  test('Axis statement generated SMS with Total amt and Min amt due', () {
    const body =
        'Your statement for Axis Bank Credit Card no. XX4821 is generated.\n'
        'Due on: 30-10-26\nTotal amt: INR  Dr. 5432.10\n'
        'Min amt due: INR  Dr. 109.00\nPay at axis.bank.in/ccpaynow\n'
        'To view fees & charges: axis.bank.in/kfs\n'
        'To view/download statement: https://ccm.axis.bank.in/AXISBK/Xy12AbCd';
    final d = registry.cardDue(body, 'VK-AXISBK-S', at);
    expect(d, isNotNull);
    expect(d!.bank, 'Axis Bank');
    expect(d.last4, '4821');
    expect(d.totalDueMinor, 543210);
    expect(d.minDueMinor, 10900);
    expect(d.dueEpochDay, day(2026, 10, 30));
    // It is a bill notice, never a spend or a payment.
    expect(d.paymentMinor, isNull);
    expect(registry.parse(body, 'VK-AXISBK-S', at, Source.sms), isNull);
  });

  test('statement mail with masked number and pipe separated labels', () {
    const body =
        'Statement for your HDFC Bank Credit Card 5241 36XX XXXX 1234\n'
        'Total Amount Due | Rs. 12,345.00\nMinimum Amount Due | Rs. 620.00\n'
        'Payment Due Date | 21/10/2026\nStatement Date | 02/10/2026\n'
        'Credit Limit Rs. 2,00,000.00';
    final d = registry.cardDue(
      body,
      'HDFC Bank <emailstatements.cards@hdfcbank.net>',
      at,
    );
    expect(d, isNotNull);
    expect(d!.last4, '1234');
    expect(d.totalDueMinor, 1234500);
    expect(d.minDueMinor, 62000);
    expect(d.dueEpochDay, day(2026, 10, 21));
    expect(d.statementEpochDay, day(2026, 10, 2));
  });

  test('statement mail naming the card by product only keeps the bank', () {
    const body =
        'Your Axis Bank Flipkart Credit Card statement is ready. Total Payment '
        'Due: Rs 8,100.50 Min Amt Due: Rs 405.00 Payment Due Date: Oct 21, 2026';
    final d = registry.cardDue(body, 'VK-AXISBK-S', at);
    expect(d, isNotNull);
    expect(d!.bank, 'Axis Bank');
    expect(d.last4, '');
    expect(d.totalDueMinor, 810050);
    expect(d.dueEpochDay, day(2026, 10, 21));
  });

  test('a payment notice without a card number is not recorded', () {
    expect(
      registry.cardDue(
        'Payment of Rs.5,000.00 has been received towards your Axis Bank Credit '
            'Card. Thank you.',
        'VK-AXISBK-S',
        at,
      ),
      isNull,
    );
  });

  test('top-level parseCardDue matches the registry', () {
    final d = parseCardDue(
      'Axis Bank Credit Card No. XX3190: Total payment due INR 8,100.00. '
          'Minimum payment due INR 405.00. Due date 02-10-2026.',
      'AX-AXISBK',
      at,
    );
    expect(d?.totalDueMinor, 810000);
  });
}

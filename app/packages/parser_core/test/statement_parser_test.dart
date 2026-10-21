// Statement rows, summaries and investment SMS. Port of StatementParserTest
// and the statement row test of SmsToTransactionTest that Phase 1 skipped
// (FR-05-03, FR-05-04, FR-05-06, FR-05-14, TC-05-02..04, TC-05-06).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';
import 'support/statement_support.dart';

void main() {
  const parser = StatementParser();

  test('credit card statement rows become card transactions', () {
    final text = dedent(r'''
      HDFC Bank Credit Card Statement
      Card No: 4893 XXXX XXXX 5678
      Statement Date 20/09/2026  Total Amount Due 12,345.00  Minimum Amount Due 620.00
      Date Transaction Description Amount (in Rs.)
      02/09/2026 AMAZON PAY INDIA MUMBAI 1,499.00
      05/09/2026 SWIGGY BANGALORE 456.50
      10/09/2026 PAYMENT RECEIVED - THANK YOU 8,000.00 Cr
      12/09/2026 REFUND FLIPKART 299.00 Cr
    ''');
    final r =
        parser.parse(text, 'HDFC Bank <statements@hdfcbank.net>', receivedAt);
    expect(r.kind, AccountKind.card);
    expect(r.last4, '5678');
    expect(r.bankName, 'HDFC Bank');
    expect(r.transactions, hasLength(4));
    final [amazon, swiggy, payment, refund] = r.transactions;
    expect(amazon.amountMinor, 149900);
    expect(amazon.type, TransactionType.debit);
    expect(swiggy.amountMinor, 45650);
    expect(payment.type, TransactionType.transfer);
    expect(refund.type, TransactionType.credit);
    expect(
      r.transactions.every(
        (t) => t.source == Source.statement && t.accountLast4 == '5678',
      ),
      isTrue,
    );
    // noon IST, not explicit, confidence 0.7 (TC-05-03)
    expect(amazon.transactionTime, istMs(2026, 9, 2, 12));
    expect(amazon.hasExplicitTime, isFalse);
    expect(amazon.confidence, 0.7);
    expect(r.lines.first, startsWith('02/09/2026 AMAZON'));
  });

  test('bank statement direction comes from the running balance', () {
    final text = dedent(r'''
      State Bank of India  Account Statement  A/c No XXXXXXX1234
      Date Narration Debit Credit Balance
      Opening Balance 50,000.00
      01-09-2026 UPI/526812345678/SWIGGY 450.00 49,550.00
      03-09-2026 NEFT SALARY ACME CORP 75,000.00 1,24,550.00
      05-09-2026 ATM WDL MUMBAI 2,000.00 1,22,550.00
    ''');
    final r =
        parser.parse(text, 'SBI <cbssbi.cas@alerts.sbi.co.in>', receivedAt);
    expect(r.kind, AccountKind.account);
    expect(r.last4, '1234');
    expect(r.transactions.map((t) => t.type), [
      TransactionType.debit,
      TransactionType.credit,
      TransactionType.debit,
    ]);
    expect(r.transactions.map((t) => t.amountMinor), [45000, 7500000, 200000]);
    expect(r.transactions.last.balanceMinor, 12255000);
  });

  test('rows outside the date window, zero amounts and skip lines are dropped',
      () {
    final text = dedent(r'''
      HDFC Bank Credit Card Statement
      Card No: 4893 XXXX XXXX 5678
      02/09/2020 OLD SPEND 100.00
      02/09/2026 REWARD POINTS EARNED 10.00
      05/09/2026 ZERO 0.00
      05/09/2026 X 5.00
      05/09/2026 SWIGGY BANGALORE 456.50
      30/09/2026 FUTURE SPEND 300.00
    ''');
    final r = parser.parse(text, 'HDFC Bank <s@hdfcbank.net>', receivedAt);
    expect(r.transactions, hasLength(1));
    expect(r.transactions.single.amountMinor, 45650);
  });

  test('bank statement rows become transactions with the closing balance', () {
    final text = dedent(r'''
      HDFC Bank
      Statement of Account
      Account No: XXXXXXXX2779
      Statement From 01/09/2026 To 24/09/2026
      Opening Balance Dr Count Cr Count Debits Credits Closing Bal
      25,000.00 2 1 6,240.00 85,000.00 1,03,760.00
      Date Narration Chq./Ref.No. Value Dt Withdrawal Amt. Deposit Amt. Closing Balance
      01/09/26 NEFT CR-ACME CORP SALARY 01/09/26 85,000.00 1,10,000.00
      05/09/26 UPI-SWIGGY-SWIGGY@ICICI 05/09/26 1,240.00 1,08,760.00
      10/09/26 ATM WDL MUMBAI ANDHERI 10/09/26 5,000.00 1,03,760.00
    ''');
    final r = parser.parse(
      text,
      'HDFC Bank <estatement@hdfcbank.net>',
      receivedAt,
    );
    expect(r.statementKind, StatementKind.bank);
    expect(r.last4, '2779');
    expect(r.transactions, hasLength(3), reason: '${r.transactions}');
    final [salary, food, cash] = r.transactions;
    expect(salary.type, TransactionType.credit);
    expect(salary.amountMinor, 8500000);
    expect(food.type, TransactionType.debit);
    expect(food.amountMinor, 124000);
    expect(cash.type, TransactionType.debit);
    expect(r.summary.closingMinor, 10376000);
    expect(cash.source, Source.statement);
  });

  test('CAMS CAS gives mutual fund holdings', () {
    final text = dedent(r'''
      Consolidated Account Statement
      Folio No: 1234567 / 89
      128TSDGG-Axis Bluechip Fund - Direct Growth - ISIN: INF846K01EW2(Advisor: DIRECT)
      Closing Unit Balance: 123.456 NAV on 30-Sep-2026: INR 45.67 Total Cost Value: 5,000.00 Market Value on 30-Sep-2026: INR 5,638.12
      P8DG-Parag Parikh Flexi Cap Fund - Direct Plan Growth - ISIN: INF879O01027(Advisor: DIRECT)
      Closing Unit Balance: 1,000.000 NAV on 30-Sep-2026: INR 80.10 Total Cost Value: 60,000.00 Market Value on 30-Sep-2026: INR 80,100.00
    ''');
    final r =
        parser.parse(text, 'CAMS <donotreply@camsonline.com>', receivedAt);
    expect(r.transactions, isEmpty);
    expect(r.holdings, hasLength(2));
    final axis = r.holdings.first;
    expect(axis.kind, HoldingKind.mutualFund);
    expect(axis.name, 'Axis Bluechip Fund - Direct Growth');
    expect(axis.identifier, 'INF846K01EW2');
    expect(axis.valueMinor, 563812);
    expect(axis.investedMinor, 500000);
    expect(axis.units, closeTo(123.456, 0.0001));
  });

  test('demat statement lines with an ISIN give stock holdings', () {
    final text = dedent(r'''
      NSDL Consolidated Account Statement
      ISIN Security Current Bal. Market Price Value
      INE009A01021 INFOSYS LIMITED 10 1,500.00 15,000.00
      INE002A01018 RELIANCE INDUSTRIES LTD 5 2,900.00 14,500.00
    ''');
    final r = parser.parse(text, 'NSDL <nsdl-cas@nsdl.co.in>', receivedAt);
    expect(r.holdings, hasLength(2));
    expect(r.holdings[0].kind, HoldingKind.stock);
    expect(r.holdings[0].name, 'INFOSYS LIMITED');
    expect(r.holdings[0].valueMinor, 1500000);
    expect(r.holdings[0].units, 10.0);
  });

  test(
      'card statement summary is read whether values share the line or sit '
      'below the labels', () {
    final below = dedent(r'''
      ICICI Bank Credit Card Statement  Card 4375 XXXX XXXX 9012
      Statement Date Payment Due Date Total Amount Due Minimum Amount Due
      20/09/2026 08/10/2026 24,560.75 1,230.00
      Credit Limit: 2,00,000.00  Available Credit Limit: 1,75,439.25
      02/09/2026 MYNTRA BANGALORE 2,499.00
    ''');
    final r = parser.parse(
      below,
      'ICICI Bank <cards@icicibank.com>',
      receivedAt,
    );
    expect(r.statementKind, StatementKind.creditCard);
    expect(r.summary.totalDueMinor, 2456075);
    expect(r.summary.minDueMinor, 123000);
    expect(r.summary.dueDate, const CivilDate(2026, 10, 8));
    expect(r.summary.statementDate, const CivilDate(2026, 9, 20));
    expect(r.summary.creditLimitMinor, 20000000);
    expect(r.summary.availableMinor, 17543925);
    expect(r.transactions, hasLength(1));
  });

  test(
      'bank statement summary gives opening, debits, credits and closing, '
      'not the table header', () {
    final text = dedent(r'''
      HDFC Bank Statement of account  Account No : 50100012345678
      Date Narration Chq./Ref.No. Value Dt Withdrawal Amt. Deposit Amt. Closing Balance
      02/09/26 UPI-SWIGGY-SWIGGY@ICICI 0000123 02/09/26 450.00 49,550.00
      STATEMENT SUMMARY
      Opening Balance Dr Count Cr Count Debits Credits Closing Bal
      50,000.00 1 0 450.00 0.00 49,550.00
    ''');
    final s = parser
        .parse(
          text,
          'HDFC Bank <hdfcbanksmartstatement@hdfcbank.net>',
          receivedAt,
        )
        .summary;
    expect(s.openingMinor, 5000000);
    expect(s.debitsMinor, 45000);
    expect(s.creditsMinor, 0);
    expect(s.closingMinor, 4955000);
  });

  test(
      'card summary with a previous balance column keeps each value with its '
      'label', () {
    final text = dedent(r'''
      Axis Bank Credit Card Statement  Card No 5241 XXXX XXXX 3344
      Previous Balance Payments/Credits Purchases/Debits Total Amount Due
      10,000.00 10,000.00 3,250.50 3,250.50
    ''');
    final s = parser
        .parse(text, 'Axis Bank <cc.statements@axisbank.com>', receivedAt)
        .summary;
    expect(s.openingMinor, 1000000);
    expect(s.creditsMinor, 1000000);
    expect(s.debitsMinor, 325050);
    expect(s.totalDueMinor, 325050);
  });

  test('CAS is an investment statement', () {
    final r = parser.parse(
      'Consolidated Account Statement\n'
          'INE009A01021 INFOSYS LIMITED 10 1,500.00 15,000.00',
      'NSDL <cas@nsdl.co.in>',
      receivedAt,
    );
    expect(r.statementKind, StatementKind.investment);
  });

  test('unknown text is OTHER with the sender as the bank name', () {
    final r = parser.parse('Hello there', 'Someone <a@b.com>', receivedAt);
    expect(r.statementKind, StatementKind.other);
    expect(r.bankName, 'Someone');
    expect(r.transactions, isEmpty);
  });

  test('parseStatement is the same as StatementParser.parse', () {
    final r = parseStatement(
      'Consolidated Account Statement\n'
          'INE009A01021 INFOSYS LIMITED 10 1,500.00 15,000.00',
      'NSDL <cas@nsdl.co.in>',
      receivedAt,
    );
    expect(r.holdings, hasLength(1));
  });

  test('NPS holding SMS updates the NPS balance', () {
    final h = InvestmentParser.parse(
      'Your NPS a/c PRAN XXXXXXXX1234 holding value as on 30-09-2026 is Rs. '
          '4,56,789.12. Login to view details.',
      'VM-NPSTRS',
      receivedAt,
    );
    expect(h!.kind, HoldingKind.nps);
    expect(h.valueMinor, 45678912);
    expect(h.identifier, 'NPS:1234');
  });

  test('EPFO passbook SMS updates the EPF balance', () {
    final h = InvestmentParser.parse(
      'Dear 10XXXXXX1234, your passbook balance against '
          'MH/BAN/0012345/000/0001234 is Rs. 1,23,456/-. Contribution of Rs. '
          '12,345/- for due month 082026 has been received.',
      'VM-EPFOHO',
      receivedAt,
    );
    expect(h, isNotNull);
    expect(h!.kind, HoldingKind.epf);
    expect(h.valueMinor, 12345600);
    expect(h.contributionMinor, 1234500);
    expect(
      InvestmentParser.parse(
        'Your passbook balance is Rs 500',
        'VM-HDFCBK',
        receivedAt,
      ),
      isNull,
    );
  });
}

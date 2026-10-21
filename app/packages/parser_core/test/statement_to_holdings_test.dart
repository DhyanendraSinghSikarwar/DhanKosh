// Statement text (as read from the PDF or spreadsheet) through StatementParser:
// the holdings and deposits it yields. Port of StatementToHoldingsTest
// (FR-05-14, FR-05-17, TC-05-11, TC-05-13, TC-05-15).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';
import 'support/statement_support.dart';

void main() {
  const parser = StatementParser();
  final at = receivedAt;

  test('EPF member passbook gives one EPF holding with value and contributions',
      () {
    final text = dedent('''
      Employees' Provident Fund Organisation, India
      Member Passbook
      Establishment ID/Name MHBAN0012345000 / ACME SOFTWARE PVT LTD
      Member ID/Name MHBAN00123450000001234 / A SHARMA
      UAN 100123451234
      Wage Month Transaction Date Transaction Type Particulars EPF Wages EPS Wages Employee Share Employer Share Pension Contribution
      OB Int. Updated upto 31/03/2026 1,20,000 85,000 30,000
      Apr-2026 15-05-2026 CR Cont. For Due-Month 052026 15,000 15,000 1,800 550 1,250
      May-2026 15-06-2026 CR Cont. For Due-Month 062026 15,000 15,000 1,800 550 1,250
      Int. Updated upto 31/03/2026 9,000 2,700 0
      Total Contributions for the year [2026] 3,600 1,100 2,500
      Closing Balance as on 30/09/2026 1,34,400 89,350 32,500
    ''');
    final r = parser.parse(text, 'EPFO <no-reply@epfindia.gov.in>', at);
    expect(r.statementKind, StatementKind.investment);
    expect(r.transactions, isEmpty, reason: 'contributions are not bank txns');
    expect(r.holdings, hasLength(1));
    final h = r.holdings.single;
    expect(h.kind, HoldingKind.epf);
    // The same key the EPFO SMS gives for "MH/BAN/0012345/000/0001234".
    expect(h.identifier, 'EPF:MHBAN00123450000001234');
    expect(
      InvestmentParser.parse(
        'Dear 10XXXXXX1234, your passbook balance against '
            'MH/BAN/0012345/000/0001234 is Rs. 2,56,250/-. Contribution of '
            'Rs. 3,600/- for due month 092026 has been received.',
        'VM-EPFOHO',
        at,
      )!
          .identifier,
      h.identifier,
    );
    expect(h.valueMinor, 25625000); // 1,34,400 + 89,350 + 32,500
    expect(h.investedMinor, 25625000 - 1170000); // less this year's interest
  });

  test(
      'PPF account statement updates the PPF account balance, not transactions',
      () {
    final text = dedent('''
      State Bank of India
      Public Provident Fund Account Statement
      PPF Account No: 00000012345673456
      Statement Period 01-04-2026 to 24-09-2026
      Date Description Debit Credit Balance
      01-04-2026 Opening Balance 2,33,333.00
      05-04-2026 BY TRANSFER FROM SB 10,000.00 2,43,333.00
      05-09-2026 BY TRANSFER FROM SB 12,345.00 2,55,678.00
    ''');
    final r = parser.parse(text, 'SBI <cbssbi.info@alerts.sbi.co.in>', at);
    expect(r.statementKind, StatementKind.investment);
    expect(r.transactions, isEmpty);
    final d = r.deposits.single;
    expect(d.lender, 'SBI');
    expect(d.last4, '3456');
    expect(d.deposit!.kind, DepositKind.ppf);
    expect(d.outstandingMinor, 25567800);
  });

  test('FD advice PDF gives the deposit, its maturity and renewal', () {
    final text = dedent('''
      ICICI Bank
      Fixed Deposit Advice
      Deposit Account No: XXXXXXXX8899
      Deposit Amount: 2,50,000.00
      Rate of Interest: 7.20% p.a.
      Date of Deposit: 20-09-2026
      Maturity Date: 20-09-2028
      Maturity Amount: 2,88,945.00
      Maturity Instruction: Credit to my savings account
    ''');
    final r = parser.parse(text, 'ICICI Bank <alerts@icicibank.com>', at);
    final d = r.deposits.single;
    expect(d.lender, 'ICICI Bank');
    expect(d.last4, '8899');
    expect(d.outstandingMinor, 25000000);
    expect(d.deposit!.kind, DepositKind.fd);
    expect(d.deposit!.maturity, const CivilDate(2028, 9, 20));
    expect(d.deposit!.maturityAmountMinor, 28894500);
    expect(d.deposit!.rateBps, 720);
    expect(d.deposit!.action, DepositAction.payout);
    expect(r.transactions, isEmpty);
  });

  test('INDmoney US stocks statement is valued in rupees at its own rate', () {
    final text = dedent(r'''
      INDmoney US Stocks Account Statement
      Holdings as on 24-Sep-2026
      USD/INR: 83.50
      Symbol Name Quantity Avg Cost ($) Current Price ($) Invested Value ($) Current Value ($)
      AAPL Apple Inc 2.5000 180.00 230.10 450.00 575.25
      VOO Vanguard S&P 500 ETF 1.0000 450.00 520.00 450.00 520.00
      Total $900.00 $1,095.25
    ''');
    final r = parser.parse(text, 'INDmoney <statements@indmoney.com>', at);
    expect(r.statementKind, StatementKind.investment);
    final byId = {for (final h in r.holdings) h.identifier: h};
    expect(byId.keys.toSet(), {'US:AAPL', 'US:VOO'}, reason: '${r.holdings}');
    final aapl = byId['US:AAPL']!;
    expect(aapl.kind, HoldingKind.stock);
    expect(aapl.valueMinor, (575.25 * 83.5 * 100).round());
    expect(aapl.investedMinor, (450.0 * 83.5 * 100).round());
    expect(byId['US:VOO']!.kind, HoldingKind.etf);
  });

  test(
      'a dollar table without a rate is left out rather than counted as rupees',
      () {
    final text = dedent(r'''
      INDmoney US Stocks Account Statement
      Holdings as on 24-Sep-2026
      Symbol Name Quantity Avg Cost ($) Current Price ($) Invested Value ($) Current Value ($)
      AAPL Apple Inc 2.5000 180.00 230.10 450.00 575.25
    ''');
    expect(
      parser.parse(text, 'INDmoney <statements@indmoney.com>', at).holdings,
      isEmpty,
    );
  });

  test('CDSL CAS forwarded by INDmoney gives stocks and funds by ISIN', () {
    final text = dedent('''
      CDSL Consolidated Account Statement (CAS)
      Statement for the period from 01-08-2026 to 31-08-2026
      Holdings as on 31-08-2026
      ISIN Security Current Bal Free Bal Market Price Value
      INE002A01018 RELIANCE INDUSTRIES LTD#EQUITY SHARES 10.000 10.000 2,950.25 29,502.50
      INE040A01034 HDFC BANK LIMITED#EQUITY SHARES 20.000 20.000 1,650.00 33,000.00
      MUTUAL FUND UNITS HELD WITH RTA
      Scheme Name ISIN Folio No Closing Bal Units NAV Cumulative Amount Invested Valuation Unrealised Profit/Loss
      PPFAS Mutual Fund - Parag Parikh Flexi Cap Fund - Direct Plan Growth INF879O01027 12345678/90 1,234.567 78.1234 80,000.00 96,448.57 16,448.57
    ''');
    final r = parser.parse(text, 'INDmoney <cas@indmoney.com>', at);
    final byId = {for (final h in r.holdings) h.identifier: h};
    expect(
      byId.keys.toSet(),
      {'INE002A01018', 'INE040A01034', 'INF879O01027'},
      reason: '${r.holdings}',
    );
    expect(byId['INE002A01018']!.valueMinor, 2950250);
    expect(byId['INE040A01034']!.kind, HoldingKind.stock);
    final fund = byId['INF879O01027']!;
    expect(fund.kind, HoldingKind.mutualFund);
    expect(fund.valueMinor, 9644857);
    expect(fund.investedMinor, 8000000);
  });

  test('Groww stocks holdings table keys stocks by name', () {
    final text = dedent('''
      Groww
      Stocks Holdings Statement
      Holdings as on 24-Sep-2026
      Stock Name Quantity Average Buy Price Buy Value Closing Price Closing Value Unrealised P&L
      Reliance Industries 10 2,500.00 25,000.00 2,950.25 29,502.50 4,502.50
    ''');
    final h =
        parser.parse(text, 'Groww <noreply@groww.in>', at).holdings.single;
    expect(h.kind, HoldingKind.stock);
    expect(h.identifier, 'STOCK:RELIANCE INDUSTRIES');
    expect(h.valueMinor, 2950250);
    expect(h.investedMinor, 2500000);
    expect(h.units, isNotNull);
  });
}

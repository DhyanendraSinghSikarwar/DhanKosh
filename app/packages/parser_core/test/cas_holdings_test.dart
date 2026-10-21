// CAS (CDSL, NSDL, CAMS) holdings and spreadsheet-to-lines. Port of
// CasHoldingsTest (FR-05-05, FR-05-14, TC-05-05, TC-05-11).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';
import 'support/statement_support.dart';

void main() {
  const parser = StatementParser();
  final received = istMs(2026, 6, 3, 9, 30);

  // The text PdfBox gives for a CDSL CAS: demat holdings, then mutual fund
  // units held with the RTA.
  final cdslCas = dedent('''
    CDSL
    Consolidated Account Statement
    Statement for the period from 01-05-2026 to 31-05-2026
    Holdings as on 31-05-2026
    DP Name : EXAMPLE BROKING LIMITED   BO ID : 1208160012345678
    STATEMENT OF TRANSACTIONS FOR THE PERIOD FROM 01-05-2026 TO 31-05-2026
    Date Transaction Particulars Debit Credit Balance
    05-05-2026 INE040A01034 HDFC BANK LTD BY CM 5.000 25.000
    HOLDING STATEMENT AS ON 31-05-2026
    ISIN Security Current Bal. Frozen Bal. Pledge Bal. Pledge Setup Bal. Free Bal. Lock-in Bal. Earmarked Bal. Market Price / Face Value Value (₹)
    INE002A01018 RELIANCE INDUSTRIES LIMITED#EQUITY SHARES 10.000 -- -- -- 10.000 -- -- 2,950.25 29,502.50
    INF204KB14I2 NIPPON INDIA ETF NIFTY 50 BEES 100.000 -- -- -- 100.000 -- -- 285.40 28,540.00
    INE040A01034 HDFC BANK LIMITED#EQUITY SHARES 25.000 -- -- -- 25.000 -- -- 1,912.80 47,820.00
    Portfolio Value ₹ 1,05,862.50
    MUTUAL FUND UNITS HELD WITH MF/RTA
    Scheme Name ISIN Folio No. Closing Bal. (Units) NAV (₹) Cumulative Amount Invested (₹) Valuation (₹) Unrealised Profit/(Loss) (₹) Annualised XIRR
    Parag Parikh Flexi Cap Fund - Direct Plan Growth INF879O01027 12345678/90 1,234.567 78.1234 80,000.00 96,448.57 16,448.57 14.20%
    Axis Bluechip Fund - Direct
    Plan Growth INF846K01EW2 91012345678
    500.000 52.10 20,000.00 26,050.00 6,050.00 9.10%
  ''');

  test('CDSL CAS gives every holding with its value', () {
    final r = parser.parse(cdslCas, 'CDSL <eCAS@cdslstatement.com>', received);
    expect(r.statementKind, StatementKind.investment);
    expect(r.transactions, isEmpty);
    expect(r.holdings, hasLength(5), reason: '${r.holdings}');
    final byIsin = {for (final h in r.holdings) h.identifier: h};

    final reliance = byIsin['INE002A01018']!;
    expect(reliance.name, 'RELIANCE INDUSTRIES LIMITED');
    expect(reliance.kind, HoldingKind.stock);
    expect(reliance.units, 10.0);
    expect(reliance.valueMinor, 2950250);

    final bees = byIsin['INF204KB14I2']!;
    expect(bees.kind, HoldingKind.etf);
    expect(bees.units, 100.0); // not the "50" in its name
    expect(bees.valueMinor, 2854000);

    // The transaction row above the holdings does not stand in for the HDFC
    // Bank holding.
    expect(byIsin['INE040A01034']!.valueMinor, 4782000);

    final ppfas = byIsin['INF879O01027']!;
    expect(ppfas.name, 'Parag Parikh Flexi Cap Fund - Direct Plan Growth');
    expect(ppfas.kind, HoldingKind.mutualFund);
    expect(ppfas.units, closeTo(1234.567, 0.0001)); // not the folio number
    expect(ppfas.valueMinor, 9644857); // the valuation, not the gain after it
    expect(ppfas.investedMinor, 8000000);

    // Name split over two lines, figures wrapped onto the next line, and a
    // digits-only folio.
    final axis = byIsin['INF846K01EW2']!;
    expect(axis.name, 'Axis Bluechip Fund - Direct Plan Growth');
    expect(axis.units, 500.0);
    expect(axis.valueMinor, 2605000);
    expect(axis.investedMinor, 2000000);

    expect(
      r.holdings.fold<int>(0, (a, h) => a + (h.valueMinor ?? 0)),
      22836107,
    );
    // Values are as on the statement date, not the day the email came.
    final asOf = istMs(2026, 5, 31, 12);
    expect(r.holdings.every((h) => h.asOf == asOf), isTrue);
  });

  test('NSDL CAS mutual fund folio rows give value and cost', () {
    final text = dedent('''
      NSDL Consolidated Account Statement
      Mutual Fund Folios (F)
      ISIN ISIN Description Folio No. No. of Units Average Cost Per Units (₹) Total Cost (₹) Current NAV per unit (₹) Current Value (₹) Unrealised Profit/(Loss) (₹)
      INF179K01BE2 HDFC Mid-Cap Opportunities Fund - Direct Plan - Growth 1234567/89 500.000 50.00 25,000.00 150.234 75,117.00 50,117.00
    ''');
    final h = parser
        .parse(text, 'NSDL <nsdl-cas@nsdl.co.in>', receivedAt)
        .holdings
        .single;
    expect(h.name, 'HDFC Mid-Cap Opportunities Fund - Direct Plan - Growth');
    expect(h.units, 500.0);
    expect(h.valueMinor, 7511700);
    expect(h.investedMinor, 2500000);
  });

  test('CAMS closing balance wrapped over lines is still read', () {
    final text = dedent('''
      Consolidated Account Statement
      P8DG-Parag Parikh Flexi Cap Fund - Direct Plan Growth - ISIN: INF879O01027(Advisor: DIRECT) Registrar : CAMS
      Folio No: 12345678 / 90
      Closing Unit Balance: 1,000.000
      NAV on 31-May-2026: INR 80.10
      Total Cost Value: 60,000.00 Market Value on 31-May-2026: INR 80,100.00
    ''');
    final h = parser
        .parse(text, 'CAMS <donotreply@camsonline.com>', received)
        .holdings
        .single;
    expect(h.name, 'Parag Parikh Flexi Cap Fund - Direct Plan Growth');
    expect(h.valueMinor, 8010000);
    expect(h.investedMinor, 6000000);
  });

  test('CAMS closing balance without a market value is valued at units x NAV',
      () {
    final text = dedent('''
      Consolidated Account Statement
      Axis Bluechip Fund - Direct Growth - ISIN: INF846K01EW2(Advisor: DIRECT)
      Closing Unit Balance: 200.000 NAV on 31-May-2026: INR 52.10
    ''');
    final h = parser
        .parse(text, 'CAMS <donotreply@camsonline.com>', received)
        .holdings
        .single;
    expect(h.valueMinor, 1042000);
    expect(h.investedMinor, isNull);
  });

  // Spreadsheets.

  test('xls style bank rows become statement transactions', () {
    final rows = [
      ['HDFC BANK Ltd.', '', 'Statement of account'],
      ['Account No :', '50100012345678'],
      [
        'Date', 'Narration', 'Chq./Ref.No.', 'Value Dt', 'Withdrawal Amt.', //
        'Deposit Amt.', 'Closing Balance',
      ],
      [
        '01/09/26',
        'UPI-SWIGGY-swiggy@icici-ICIC0000001-123456789012',
        '0000123456789012',
        '01/09/26',
        '450',
        '',
        '52340.5',
      ],
      [
        '03/09/26', 'NEFT CR-ACME CORP-SALARY SEP', 'N123456', '03/09/26', //
        '0', '85000', '137340.5',
      ],
    ];
    final lines = SpreadsheetLines.toLines(rows);
    expect(
      lines.any((l) => l.contains('450.00 Dr') && l.endsWith('52340.50')),
      isTrue,
      reason: lines.join('\n'),
    );
    final r = parser.parse(
      lines.join('\n'),
      'HDFC Bank <emailstatements.cc@hdfcbank.net>',
      receivedAt,
    );
    expect(r.transactions, hasLength(2), reason: '${r.transactions}');
    expect(r.transactions[0].type, TransactionType.debit);
    expect(r.transactions[0].amountMinor, 45000);
    expect(r.transactions[1].type, TransactionType.credit);
    expect(r.transactions[1].amountMinor, 8500000);
  });

  test('excel day serials in a date column become dates', () {
    expect(SpreadsheetLines.serialDate('46000'), '09/12/2025');
    final lines = SpreadsheetLines.toLines([
      ['Txn Date', 'Description', 'Debit', 'Credit', 'Balance'],
      ['46000', 'ATM WDL', '2000', '', '10000'],
    ]);
    expect(lines.last, '09/12/2025  ATM WDL  2000.00 Dr  10000.00');
  });

  test('csv with quoted commas is split into cells', () {
    final rows = SpreadsheetLines.parseCsv(
      '﻿Date,Description,Amount,Type\r\n'
      '"05/09/2026","AMAZON, PAY","1,499.00",DR\r\n',
    );
    expect(rows[1], ['05/09/2026', 'AMAZON, PAY', '1,499.00', 'DR']);
    expect(
      SpreadsheetLines.toLines(rows).last,
      '05/09/2026  AMAZON, PAY  1499.00  DR',
    );
  });
}

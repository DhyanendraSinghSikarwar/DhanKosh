// NPS SMS and statements, Groww holdings. Port of NpsAndGrowwHoldingsTest
// (FR-05-14, FR-06-15, TC-05-12, TC-05-13).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';
import 'support/statement_support.dart';

void main() {
  const parser = StatementParser();

  test('CRA senders are routed to the investment parser', () {
    for (final s in [
      'AX-NPSCRA', 'VM-NSDLPR', 'JD-PFRDAI', 'VM-KFINTN', 'AD-CAMSNP', //
      'BZ-NPSTRS',
    ]) {
      expect(InvestmentParser.accepts(s), isTrue, reason: s);
    }
    expect(InvestmentParser.accepts('VM-HDFCBK'), isFalse);
  });

  test('Protean contribution SMS is a Tier I contribution', () {
    const body =
        'Dear Subscriber, Contribution of Rs.5000.00 for PRAN XXXXXXXX1234 has '
        'been credited to your Tier I account on 22-09-2026 and units '
        'allotted. -NPSCRA';
    final c = InvestmentParser.npsContribution(body, receivedAt);
    expect(c, isNotNull);
    expect(c!.pranLast4, '1234');
    expect(c.tier, 1);
    expect(c.amountMinor, 500000);
    expect(c.date, const CivilDate(2026, 9, 22));
    expect(c.identifier, 'NPS:1234');
  });

  test('KFintech Tier II contribution SMS', () {
    const body =
        'Units for Rs 2,000.00 contribution in PRAN 1100XXXX5678 Tier II have '
        'been allotted on 20-Sep-2026. - KFin CRA';
    final c = InvestmentParser.npsContribution(body, receivedAt)!;
    expect(c.pranLast4, '5678');
    expect(c.tier, 2);
    expect(c.amountMinor, 200000);
    expect(c.identifier, 'NPS:5678:T2');
    expect(InvestmentParser.parse(body, 'VM-KFINTN', receivedAt), isNull);
  });

  test('holding value SMS with the value before the PRAN', () {
    const body =
        'Total holding value Rs 4,56,789.00 as on 24-Sep-2026 for PRAN '
        'XXXXXXXX1234. -NPS Trust';
    expect(InvestmentParser.npsContribution(body, receivedAt), isNull);
    final h = InvestmentParser.parse(body, 'JD-NPSTRS', receivedAt)!;
    expect(h.kind, HoldingKind.nps);
    expect(h.identifier, 'NPS:1234');
    expect(h.valueMinor, 45678900);
  });

  test('failed contribution is ignored', () {
    expect(
      InvestmentParser.npsContribution(
        'Your contribution of Rs 5000 for PRAN XXXX1234 has failed. -NPSCRA',
        receivedAt,
      ),
      isNull,
    );
  });

  final npsSot = dedent(r'''
    NPS Transaction Statement for Tier I Account
    Protean eGov Technologies Limited - Central Recordkeeping Agency
    PRAN : 110012341234
    Subscriber Name : A SHARMA
    Statement Date : 24-Sep-2026
    Holdings as on 24-Sep-2026
    Current Valuation Summary
    Total Contribution (Rs) Total Withdrawal (Rs) Total Notional Gain/Loss (Rs) Value of your Holdings (Investment) as on 24-Sep-2026 (in Rs) Return on investment (XIRR)
    3,50,000.00 0.00 1,06,789.12 4,56,789.12 10.25%
    Investment Details - Scheme Wise Summary
    Scheme Name Total Units NAV (Rs) Value at NAV (Rs)
    SBI PENSION FUND SCHEME E - TIER I 4,000.0000 50.0000 2,00,000.00
    LIC PENSION FUND SCHEME C - TIER I 6,000.0000 30.0000 1,80,000.00
    HDFC PENSION FUND SCHEME G - TIER I 2,000.0000 38.3945 76,789.12
    Tier II Account
    Total Contribution (Rs) Total Withdrawal (Rs) Total Notional Gain/Loss (Rs) Value of your Holdings (Investment) as on 24-Sep-2026 (in Rs)
    50,000.00 0.00 6,789.00 56,789.00
    SBI PENSION FUND SCHEME E - TIER II 1,135.7800 50.0000 56,789.00
    Transaction Details
    22-Sep-2026 By Voluntary Contributions 5,000.00 100.0000 50.0000
  ''');

  test('NPS statement of transaction gives value and contributions per tier',
      () {
    final r = parser.parse(
      npsSot,
      'NPS CRA <statements@npscra.nsdl.co.in>',
      receivedAt,
    );
    expect(r.statementKind, StatementKind.investment);
    expect(r.transactions, isEmpty);
    final byId = {for (final h in r.holdings) h.identifier: h};
    expect(
      byId.keys.toSet(),
      {'NPS:1234', 'NPS:1234:T2'},
      reason: '${r.holdings}',
    );
    final t1 = byId['NPS:1234']!;
    expect(t1.kind, HoldingKind.nps);
    expect(t1.valueMinor, 45678912);
    expect(t1.investedMinor, 35000000);
    final t2 = byId['NPS:1234:T2']!;
    expect(t2.valueMinor, 5678900);
    expect(t2.investedMinor, 5000000);
  });

  test('Groww holdings PDF text gives units, invested and current value', () {
    final text = dedent(r'''
      Groww
      Mutual Fund Holdings Statement
      Holdings as on 24-Sep-2026
      Scheme Name AMC Category Folio No. Units Invested Value Current Value Returns XIRR
      Parag Parikh Flexi Cap Fund Direct Growth PPFAS Mutual Fund Equity 12345678 1,234.567 80,000.00 96,445.12 16,445.12 14.25%
      Axis Small Cap Fund Direct Growth Axis Mutual Fund Equity 91011121 500.000 25,000.00 23,500.00 -1,500.00 -4.10%
      Total 1,05,000.00 1,19,945.12 14,945.12
    ''');
    final r = parser.parse(text, 'Groww <noreply@groww.in>', receivedAt);
    expect(r.statementKind, StatementKind.investment);
    expect(r.holdings, hasLength(2), reason: '${r.holdings}');
    final ppfas = r.holdings.firstWhere(
      (h) =>
          h.identifier ==
          MfOrderParser.identifierFor(
              'Parag Parikh Flexi Cap Fund Direct Growth'),
    );
    expect(ppfas.kind, HoldingKind.mutualFund);
    expect(ppfas.name, 'Parag Parikh Flexi Cap Fund Direct Growth');
    expect(ppfas.units, closeTo(1234.567, 1e-6));
    expect(ppfas.investedMinor, 8000000);
    expect(ppfas.valueMinor, 9644512);
    final axis =
        r.holdings.firstWhere((h) => h.name.startsWith('Axis Small Cap'));
    expect(axis.units, closeTo(500.0, 1e-6));
    expect(axis.investedMinor, 2500000);
    expect(axis.valueMinor, 2350000);
  });

  test('Groww holdings XLSX rows give units, invested and current value', () {
    final rows = [
      ['Holdings statement as on 24-09-2026'],
      [
        'Scheme Name', 'AMC', 'Category', 'Sub-category', 'Folio No.', //
        'Source', 'Units', 'Invested Value', 'Current Value', 'Returns',
        'XIRR',
      ],
      [
        'Parag Parikh Flexi Cap Fund Direct Growth', 'PPFAS Mutual Fund', //
        'Equity', 'Flexi Cap', '12345678', 'Groww', '1234.567', '80000',
        '96445.12', '16445.12', '14.25%',
      ],
      [
        'HDFC Index Fund Nifty 50 Direct Plan', 'HDFC Mutual Fund', 'Equity', //
        'Index', '87654321', 'External', '100.5', '20000', '21000', '1000', '',
      ],
    ];
    final r = parser.parse(
      SpreadsheetLines.toText(rows),
      'Groww <noreply@groww.in>',
      receivedAt,
    );
    expect(r.holdings, hasLength(2), reason: '${r.holdings}');
    final ppfas = r.holdings.firstWhere(
      (h) => h.name == 'Parag Parikh Flexi Cap Fund Direct Growth',
    );
    expect(ppfas.units, closeTo(1234.567, 1e-6));
    expect(ppfas.investedMinor, 8000000);
    expect(ppfas.valueMinor, 9644512);
    expect(ppfas.platform, 'Groww');
    final hdfc = r.holdings.firstWhere(
      (h) => h.identifier == 'MF:hdfc index nifty 50',
    );
    expect(hdfc.units, closeTo(100.5, 1e-6));
    expect(hdfc.investedMinor, 2000000);
    expect(hdfc.valueMinor, 2100000);
  });

  test('CAMS CAS cost value with a currency label is the amount invested', () {
    final text = dedent(r'''
      Consolidated Account Statement
      Folio No: 1234567 / 89
      P123-Parag Parikh Flexi Cap Fund - Direct Plan Growth - ISIN: INF879O01027(Advisor: DIRECT)
      Closing Unit Balance: 1,234.567 NAV on 24-Sep-2026: INR 78.1234 Cost Value (INR): 80,000.00 Market Value on 24-Sep-2026: INR 96,448.57
    ''');
    final h = parser
        .parse(text, 'CAMS <donotreply@camsonline.com>', receivedAt)
        .holdings
        .single;
    expect(h.identifier, 'INF879O01027');
    expect(h.investedMinor, 8000000);
    expect(h.valueMinor, 9644857);
  });

  test('Groww and NPS statement subjects are fetched', () {
    expect(
      ParserRegistry.isStatementSubject('Your Groww mutual fund statement'),
      isTrue,
    );
    expect(
      ParserRegistry.isStatementSubject(
          'Holdings statement for September 2026'),
      isTrue,
    );
    expect(
      ParserRegistry.isStatementSubject('NPS Statement of Transaction'),
      isTrue,
    );
    expect(
      ParserRegistry.isStatementSubject('NPS contribution credited'),
      isTrue,
    );
  });
}

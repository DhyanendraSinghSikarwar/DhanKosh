// Groww-style holdings export (Personal Details, HOLDING SUMMARY, HOLDINGS AS
// ON ...), read as rows or as text lines. Port of HoldingsSheetTest
// (FR-05-05, FR-05-14, FR-05-18, TC-05-12, TC-05-16).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

void main() {
  const parser = StatementParser();
  const sender = 'Groww <noreply@groww.in>';

  const head = [
    'Scheme Name', 'AMC', 'Category', 'Sub-category', 'Folio No.', 'Source', //
    'Units', 'Invested Value', 'Current Value', 'Returns', 'XIRR',
  ];

  // scheme, amc, category, sub-category, folio, source, units, invested,
  // current. One scheme has one NAV in all its folios.
  const data = [
    [
      'ICICI Prudential Retirement Fund Hybrid Aggressive Plan Direct Growth',
      'ICICI Prudential Mutual Fund',
      'Hybrid',
      'Aggressive Hybrid',
      '1001',
      'Groww',
      '300',
      '30000',
      '33150'
    ],
    [
      'Parag Parikh Flexi Cap Fund Direct Growth',
      'PPFAS Mutual Fund',
      'Equity',
      'Flexi Cap',
      '2002',
      'Groww',
      '400',
      '24000',
      '30400'
    ],
    [
      'Parag Parikh Flexi Cap Fund Direct Growth',
      'PPFAS Mutual Fund',
      'Equity',
      'Flexi Cap',
      '2003',
      'Groww',
      '100',
      '6500',
      '7600'
    ],
    [
      'SBI Gold Direct Plan Growth',
      'SBI Mutual Fund',
      'Commodities',
      'Gold',
      '3001',
      'Groww',
      '1500',
      '22500',
      '24600'
    ],
    [
      'SBI Gold Direct Plan Growth',
      'SBI Mutual Fund',
      'Commodities',
      'Gold',
      '3002',
      'External',
      '500',
      '7000',
      '8200'
    ],
    [
      'Invesco India PSU Equity Fund Direct Growth',
      'Invesco Mutual Fund',
      'Equity',
      'Sectoral/Thematic',
      '4001',
      'Groww',
      '250',
      '12500',
      '14250'
    ],
    [
      'Invesco India PSU Equity Fund Direct Growth',
      'Invesco Mutual Fund',
      'Equity',
      'Sectoral/Thematic',
      '4002',
      'Groww',
      '50',
      '2800',
      '2850'
    ],
    [
      'LIC MF Gold ETF FoF Direct Growth',
      'LIC Mutual Fund',
      'Commodities',
      'Gold',
      '5001',
      'Groww',
      '1000',
      '15000',
      '16400'
    ],
    [
      'LIC MF Gold ETF FoF Direct Growth',
      'LIC Mutual Fund',
      'Commodities',
      'Gold',
      '5002',
      'Groww',
      '200',
      '2900',
      '3280'
    ],
    [
      'SBI Multi Asset Allocation Fund Direct Growth',
      'SBI Mutual Fund',
      'Hybrid',
      'Multi Asset Allocation',
      '6001',
      'Groww',
      '600',
      '30000',
      '32400'
    ],
    [
      'SBI Multi Asset Allocation Fund Direct Growth',
      'SBI Mutual Fund',
      'Hybrid',
      'Multi Asset Allocation',
      '6002',
      'Groww',
      '100',
      '5500',
      '5400'
    ],
    [
      'Axis Small Cap Fund Direct Growth',
      'Axis Mutual Fund',
      'Equity',
      'Small Cap',
      '7001',
      'Groww',
      '500',
      '25000',
      '23500'
    ],
  ];
  const totalInvested = 183700.0;
  const totalValue = 202030.0;

  String fmt(double v) => v == v.floorToDouble() ? v.toInt().toString() : '$v';

  List<String> row(List<String> d) => [
        ...d,
        fmt(double.parse(d[8]) - double.parse(d[7])),
        '9.5%',
      ];

  List<List<String>> sheet({
    (String, String) totals = ('183700', '202030'),
    String asOn = '2026-10-06',
  }) =>
      [
        ['Personal Details'],
        ['Name', ''],
        ['Mobile Number', ''],
        ['PAN', ''],
        [''],
        ['HOLDING SUMMARY'],
        [
          'Total Investments',
          'Current Portfolio Value',
          'Profit/Loss',
          'Profit/Loss %',
          'XIRR'
        ],
        [
          totals.$1,
          totals.$2,
          fmt(totalValue - totalInvested),
          '9.98%',
          '7.84%'
        ],
        [''],
        ['HOLDINGS AS ON $asOn'],
        head,
        for (final d in data) row(d),
      ];

  int sum(Iterable<int?> xs) => xs.fold<int>(0, (a, b) => a + b!);

  void assertSheet(StatementResult r) {
    expect(r.statementKind, StatementKind.investment);
    // Seven schemes: the folios of one scheme are summed, none dropped.
    expect(r.holdings, hasLength(7), reason: r.holdings.join('\n'));
    HoldingSnapshot h(String name) =>
        r.holdings.singleWhere((x) => x.name == name);
    final ppfas = h('Parag Parikh Flexi Cap Fund Direct Growth');
    expect(ppfas.units, closeTo(500.0, 1e-6));
    expect(ppfas.investedMinor, 3050000);
    expect(ppfas.valueMinor, 3800000);
    expect(
      ppfas.identifier,
      MfOrderParser.identifierFor('Parag Parikh Flexi Cap Fund Direct Growth'),
    );
    expect(ppfas.kind, HoldingKind.mutualFund);
    final gold = h('SBI Gold Direct Plan Growth');
    expect(gold.units, closeTo(2000.0, 1e-6));
    expect(gold.investedMinor, 2950000);
    expect(gold.valueMinor, 3280000);
    expect(gold.kind, HoldingKind.gold);
    expect(h('LIC MF Gold ETF FoF Direct Growth').kind, HoldingKind.gold);
    final psu = h('Invesco India PSU Equity Fund Direct Growth');
    expect(psu.units, closeTo(300.0, 1e-6));
    expect(psu.investedMinor, 1530000);
    expect(psu.valueMinor, 1710000);
    final multi = h('SBI Multi Asset Allocation Fund Direct Growth');
    expect(multi.investedMinor, 3550000);
    expect(multi.valueMinor, 3780000);
    // Totals match the HOLDING SUMMARY.
    expect(sum(r.holdings.map((x) => x.investedMinor)), 18370000);
    expect(sum(r.holdings.map((x) => x.valueMinor)), 20203000);
    final check = r.holdingsCheck!;
    expect(check.mismatch, isFalse);
    expect(check.statedInvestedMinor, 18370000);
    expect(check.statedValueMinor, 20203000);
    // Units x NAV: a scheme's value is its units at the NAV every folio was
    // priced at.
    const nav = {
      'ICICI Prudential Retirement Fund Hybrid Aggressive Plan Direct Growth':
          110.5,
      'Parag Parikh Flexi Cap Fund Direct Growth': 76.0,
      'SBI Gold Direct Plan Growth': 16.4,
      'Invesco India PSU Equity Fund Direct Growth': 57.0,
      'LIC MF Gold ETF FoF Direct Growth': 16.4,
      'SBI Multi Asset Allocation Fund Direct Growth': 54.0,
      'Axis Small Cap Fund Direct Growth': 47.0,
    };
    for (final s in r.holdings) {
      expect(nav[s.name]! * s.units!, closeTo(s.valueMinor! / 100.0, 0.01),
          reason: s.name);
    }
    expect(
      (r.holdings.first.asOf - receivedAt).abs() < 40 * 86400000,
      isTrue,
    );
  }

  test('holdings sheet rows are summed per scheme and match the summary', () {
    assertSheet(
      parser.parse(SpreadsheetLines.toText(sheet()), sender, receivedAt),
    );
  });

  test('holdings sheet as csv text', () {
    final csv = sheet()
        .map(
          (r) => r.map((c) => c.contains(',') ? '"$c"' : c).join(','),
        )
        .join('\r\n');
    assertSheet(
      parser.parse(
        SpreadsheetLines.toText(SpreadsheetLines.parseCsv(csv)),
        sender,
        receivedAt,
      ),
    );
  });

  test('holdings sheet as text lines with two-space cells', () {
    final text =
        sheet().map((r) => r.where((c) => c.isNotEmpty).join('  ')).join('\n');
    assertSheet(parser.parse(text, sender, receivedAt));
  });

  test(
      'a stated total the rows miss by more than a rupee raises the flag but '
      'keeps the rows', () {
    final r = parser.parse(
      SpreadsheetLines.toText(sheet(totals: ('183700', '205030'))),
      sender,
      receivedAt,
    );
    expect(r.holdings, hasLength(7));
    expect(r.holdingsCheck!.mismatch, isTrue);
    expect(r.holdingsCheck!.rowsValueMinor, 20203000);
    final near = parser.parse(
      SpreadsheetLines.toText(sheet(totals: ('183700.6', '202030.4'))),
      sender,
      receivedAt,
    );
    expect(near.holdingsCheck!.mismatch, isFalse);
  });

  test('a summary without usable rows invents nothing', () {
    final rows = [
      ...sheet().take(11),
      [
        'Some Fund Direct Growth',
        'AMC',
        'Equity',
        'Large Cap',
        '1',
        'Groww',
        '',
        '',
        '',
        '',
        ''
      ],
    ];
    final r = parser.parse(SpreadsheetLines.toText(rows), sender, receivedAt);
    expect(r.holdings, isEmpty, reason: '${r.holdings}');
    expect(r.holdingsCheck?.rowsValueMinor, isNull);
    expect(r.holdingsCheck?.mismatch ?? false, isFalse);
  });

  test('numbers with commas, rupee signs and brackets, header below other rows',
      () {
    final rows = [
      ['Client report'],
      ['Generated 06-Oct-2026'],
      [''],
      [
        'Fund Name',
        'Folio',
        'Platform',
        'Closing Units',
        'Total Investment',
        'Market Value',
        'P&L',
        'Returns %'
      ],
      [
        'Kotak Emerging Equity Fund Direct Growth',
        '123',
        'ET Money',
        '1,234.567',
        '₹80,000.00',
        '₹96,445.12',
        '16,445.12',
        '20.56%'
      ],
      [
        'Axis Small Cap Fund Direct Growth',
        '456',
        'ET Money',
        '500',
        '25,000',
        '23,500',
        '(1,500)',
        '(6.00%)'
      ],
      [''],
      ['Total', '', '', '', '1,05,000', '1,19,945.12', '14,945.12'],
    ];
    final r = parser.parse(
      SpreadsheetLines.toText(rows),
      'ET Money <noreply@etmoney.com>',
      receivedAt,
    );
    expect(r.holdings, hasLength(2), reason: '${r.holdings}');
    final k = r.holdings.firstWhere((h) => h.name.startsWith('Kotak'));
    expect(k.units, closeTo(1234.567, 1e-6));
    expect(k.investedMinor, 8000000);
    expect(k.valueMinor, 9644512);
    expect(
      r.holdings.firstWhere((h) => h.name.startsWith('Axis')).valueMinor,
      2350000,
    );
  });

  test('INDmoney short headers and Zerodha Coin holdings', () {
    final ind = [
      ['Fund Name', 'Invested', 'Current', 'Returns'],
      ['Nippon India Small Cap Fund Direct Growth', '40000', '52000', '12000'],
    ];
    final a = parser
        .parse(
          SpreadsheetLines.toText(ind),
          'INDmoney <no-reply@indmoney.com>',
          receivedAt,
        )
        .holdings
        .single;
    expect(a.investedMinor, 4000000);
    expect(a.valueMinor, 5200000);
    final coin = [
      [
        'Instrument',
        'Qty.',
        'Avg. cost',
        'LTP',
        'Invested',
        'Cur. val',
        'P&L',
        'Net chg.',
        'Day chg.'
      ],
      [
        'Parag Parikh Flexi Cap Fund - Direct Plan - Growth',
        '100',
        '60',
        '76',
        '6000',
        '7600',
        '1600',
        '26.67%',
        '0.30%'
      ],
    ];
    final b = parser
        .parse(
          SpreadsheetLines.toText(coin),
          'Zerodha <no-reply@zerodha.com>',
          receivedAt,
        )
        .holdings
        .single;
    expect(b.units, closeTo(100.0, 1e-6));
    expect(b.investedMinor, 600000);
    expect(b.valueMinor, 760000);
  });

  test('broker stock csv with symbol and ISIN', () {
    final rows = [
      ['Symbol', 'ISIN', 'Quantity', 'Avg price', 'LTP', 'Current value'],
      ['RELIANCE', 'INE002A01018', '10', '2500', '2900', '29000'],
      ['TCS', 'INE467B01029', '5', '3500', '4000', '20000'],
    ];
    final r = parser.parse(
      SpreadsheetLines.toText(rows),
      'Broker <no-reply@broker.in>',
      receivedAt,
    );
    expect(
      r.holdings.map((h) => h.identifier).toSet(),
      {'INE002A01018', 'INE467B01029'},
      reason: '${r.holdings}',
    );
    expect(
      r.holdings.firstWhere((h) => h.identifier == 'INE002A01018').valueMinor,
      2900000,
    );
  });

  test(
      'two statements of the same schemes give the same identifiers, one per '
      'scheme', () {
    final a = parser
        .parse(SpreadsheetLines.toText(sheet()), sender, receivedAt)
        .holdings;
    final b = parser
        .parse(
          SpreadsheetLines.toText(sheet(asOn: '2026-10-07')),
          sender,
          receivedAt,
        )
        .holdings;
    expect(
      a.map((h) => h.identifier).toList()..sort(),
      b.map((h) => h.identifier).toList()..sort(),
    );
    expect(a.length, a.map((h) => h.identifier).toSet().length);
  });
}

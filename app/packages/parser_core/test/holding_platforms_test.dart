// Holdings exports of Groww (.xlsx layout), Zerodha, Kuvera, INDmoney, brokers
// and registrars, read by column names. Port of HoldingPlatformsTest
// (FR-05-05, FR-05-14, TC-05-12).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

void main() {
  const parser = StatementParser();

  // name | AMC | category | sub | folio | units | invested | current | returns
  // | xirr, laid out as Groww's export stores them. Invented funds and
  // amounts: a scheme held in two folios, gold and silver, a 12-digit folio,
  // losses.
  final groww = '''
Alpha Bluechip Fund Direct Growth|Alpha Mutual Fund|Equity|Large Cap|10203040|120.5|12000|13450.25|1450.25|9.1%
Beta Gold Fund Direct Growth|Beta Mutual Fund|Commodities|Gold|900011122233|80.25|4000|4810.4|810.4|18.2%
Gamma Flexi Cap Fund Direct Growth|Gamma Mutual Fund|Equity|Flexi Cap|55667788|45.125|5000|4720.1|-279.9|-4.3%
Alpha Bluechip Fund Direct Growth|Alpha Mutual Fund|Equity|Large Cap|99887766|30|3000|3348.6|348.6|7.2%
Delta Silver FoF Direct Growth|Delta Mutual Fund|Commodities|Silver|412345678901|150|2500|2360.75|-139.25|-5.6%
Beta Gold Fund Direct Growth|Beta Mutual Fund|Commodities|Gold|31313131|10.5|600|629.4|29.4|4.9%
Epsilon Hybrid Fund Direct Growth|Epsilon Mutual Fund|Hybrid|Aggressive Hybrid|77001122|60.333|3500.5|3611.95|111.45|3.2%
Zeta Mid Cap Fund Direct Growth|Zeta Mutual Fund|Equity|Mid Cap|8080808|25|1999.9|2201.3|201.4|10.1%'''
      .split('\n')
      .map((l) => l.split('|'))
      .toList();

  const growwHead = [
    'Scheme Name', 'AMC', 'Category', 'Sub-category', 'Folio No.', 'Source', //
    'Units', 'Invested Value', 'Current Value', 'Returns', 'XIRR',
  ];

  List<String> withSource(List<String> r) =>
      [...r.take(5), 'Groww', ...r.skip(5)];

  // The summary states the value 2 paise off the rows' sum, as Groww's
  // rounding does.
  List<List<String>> growwSheet() => [
        [
          'Total Investments',
          'Current Portfolio Value',
          'Profit/Loss',
          'Profit/Loss %',
          'XIRR',
        ],
        ['32600.4', '35132.73', '2532.33', '7.77%', '8.4%'],
        [],
        [],
        ['HOLDINGS AS ON 2026-10-06'],
        [],
        growwHead,
        for (final r in groww) withSource(r),
      ];

  int minor(String s) => Money.parse(s)!.minor;
  int sumInt(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

  test('Groww sheet gives one holding per scheme with summed figures', () {
    final r = parser.parse(
      SpreadsheetLines.toText(growwSheet()),
      'Groww <noreply@groww.in>',
      receivedAt,
    );
    final schemes = <String, List<List<String>>>{};
    for (final row in groww) {
      schemes.putIfAbsent(row[0], () => []).add(row);
    }
    expect(
      r.holdings,
      hasLength(schemes.length),
      reason: r.holdings.join('\n'),
    );
    expect(schemes, hasLength(6));
    schemes.forEach((name, rows) {
      final h = r.holdings.singleWhere((x) => x.name == name);
      expect(
        h.units,
        closeTo(rows.fold<double>(0, (a, x) => a + double.parse(x[5])), 1e-6),
        reason: name,
      );
      expect(
        h.investedMinor,
        sumInt(rows.map((x) => minor(x[6]))),
        reason: name,
      );
      expect(h.valueMinor, sumInt(rows.map((x) => minor(x[7]))), reason: name);
      // Gain = value - invested, as the sheet's Returns column states it.
      expect(
        (h.valueMinor! - h.investedMinor!) / 100.0,
        closeTo(rows.fold<double>(0, (a, x) => a + double.parse(x[8])), 0.02),
        reason: name,
      );
      expect(
        h.kind,
        rows[0][2] == 'Commodities' ? HoldingKind.gold : HoldingKind.mutualFund,
        reason: name,
      );
      expect(h.identifier, MfOrderParser.identifierFor(name));
      expect(h.platform, 'Groww');
    });
    expect(
      r.holdings.where((x) => x.name == 'Alpha Bluechip Fund Direct Growth'),
      hasLength(1),
    );
    final gold =
        r.holdings.singleWhere((x) => x.name == 'Beta Gold Fund Direct Growth');
    expect(gold.units, closeTo(90.75, 1e-6));
    // A long folio never becomes units or value.
    expect(
      r.holdings.every((x) => x.units! < 1000 && x.valueMinor! < 5000000),
      isTrue,
    );
    expect(sumInt(r.holdings.map((x) => x.investedMinor!)), 3260040);
    expect(sumInt(r.holdings.map((x) => x.valueMinor!)), 3513275);
    final check = r.holdingsCheck!;
    expect(check.statedInvestedMinor, 3260040);
    expect(check.statedValueMinor, 3513273);
    expect(check.mismatch, isFalse);
  });

  test(
      'second Groww sheet replaces by identifier, the summary sheet of a '
      'workbook is read too', () {
    final workbook = <List<String>>[
      growwHead,
      for (final r in groww.take(3)) withSource(r),
      [],
      ['Summary'],
      ['Total Investments', '21000'],
      ['Current Value', '22980.75'],
    ];
    final r = parser.parse(
      SpreadsheetLines.toText(workbook),
      'Groww <noreply@groww.in>',
      receivedAt,
    );
    expect(r.holdings, hasLength(3));
    expect(r.holdingsCheck!.statedInvestedMinor, 2100000);
  });

  test('numbers as text with rupee signs, commas, brackets, Cr and Dr', () {
    final rows = <List<String>>[
      ['Report'],
      [],
      [
        'Scheme Name',
        'Folio',
        'Units',
        'Invested Value (₹)',
        'Current Value (₹)',
        'Returns',
      ],
      [
        'Alpha Equity Fund Direct Growth',
        '123456789012',
        '1,234.5',
        '₹ 80,000.00',
        '₹96,445.12',
        '16,445.12',
      ],
      [
        'Beta Debt Fund Direct Growth',
        '98765',
        '(10)',
        '25,000',
        '23,500 Cr',
        '(1,500.00)',
      ],
      ['Total', '', '', '105000', '119945.12', ''],
      ['Disclaimer Fund Direct Growth', '1', '1', '1', '999', '0'],
    ];
    final r = parser.parse(
      SpreadsheetLines.toText(rows),
      'Groww <a@groww.in>',
      receivedAt,
    );
    expect(r.holdings, hasLength(2), reason: '${r.holdings}');
    final a = r.holdings.singleWhere((x) => x.name.startsWith('Alpha'));
    expect(a.units, closeTo(1234.5, 1e-9));
    expect(a.valueMinor, 9644512);
    final b = r.holdings.singleWhere((x) => x.name.startsWith('Beta'));
    expect(b.valueMinor, 2350000);
    expect(b.investedMinor, 2500000);
  });

  test('csv with BOM and tab or semicolon delimiters', () {
    for (final d in ['\t', ';', ',']) {
      final csv = '﻿Symbol${d}ISIN${d}Quantity${d}Average buy price$d'
          'Closing price${d}Closing value\r\n'
          'RELIANCE${d}INE002A01018${d}10${d}2500${d}2900${d}29000\r\n';
      final h = parser
          .parse(
            SpreadsheetLines.toText(SpreadsheetLines.parseCsv(csv)),
            'Groww <a@groww.in>',
            receivedAt,
          )
          .holdings
          .single;
      expect(h.identifier, 'INE002A01018', reason: d);
      expect(h.investedMinor, 2500000, reason: d);
    }
  });

  test('transaction sheets are not holdings', () {
    final rows = [
      ['Scheme Name', 'Date', 'Type', 'Units', 'NAV', 'Amount'],
      [
        'Alpha Equity Fund Direct Growth',
        '01/09/2026',
        'Purchase',
        '10',
        '100',
        '1000',
      ],
    ];
    expect(
      parser
          .parse(
            SpreadsheetLines.toText(rows),
            'Groww <a@groww.in>',
            receivedAt,
          )
          .holdings,
      isEmpty,
    );
  });

  test('column synonyms normalise case, punctuation and unit brackets', () {
    const cases = {
      'Unrealized P&L Pct.': HoldingField.gainPct,
      'Unrealised P&L': HoldingField.gain,
      'Returns (%)': HoldingField.gainPct,
      'CURRENT VALUE (INR)': HoldingField.current,
      'Cur. val': HoldingField.current,
      'Avg. cost': HoldingField.avgPrice,
      'Average buy price': HoldingField.avgPrice,
      'Buy value': HoldingField.invested,
      'Closing value': HoldingField.current,
      'Closing price': HoldingField.price,
      'Previous Closing Price': HoldingField.price,
      'Qty.': HoldingField.units,
      'Quantity Available': HoldingField.units,
      'Folio No.': HoldingField.folio,
      'Sub-category': HoldingField.subCategory,
      'Profit/Loss %': HoldingField.gainPct,
      'Total Investments': HoldingField.invested,
      'Trading Symbol': HoldingField.symbol,
    };
    cases.forEach((h, f) {
      expect(HoldingColumns.fieldOf(h), f, reason: h);
    });
    expect(HoldingColumns.fieldOf('Quantity Long Term'), isNull);
    expect(HoldingColumns.fieldOf('Quantity Pledged (Margin)'), isNull);
  });

  List<String> sampleRow(List<String> header, String platform) => [
        for (final h in header)
          switch (HoldingColumns.fieldOf(h)) {
            HoldingField.name => 'Alpha Equity Fund Direct Growth',
            HoldingField.symbol => 'ALPHA',
            HoldingField.isin => 'INE002A01018',
            HoldingField.folio => '123456789012',
            HoldingField.source => platform,
            HoldingField.units => '10',
            HoldingField.avgPrice => '100',
            HoldingField.invested => '1000',
            HoldingField.current => '1200',
            HoldingField.price => '120',
            HoldingField.gain => '200',
            HoldingField.gainPct => '20%',
            HoldingField.xirr => '9%',
            _ => 'x',
          },
      ];

  test('every platform profile header is read and its platform named', () {
    for (final p in HoldingProfiles.all) {
      expect(HoldingColumns.isHeader(p.header), isTrue, reason: p.label);
      final sender = '${p.platform.toLowerCase().replaceAll(' ', '')}.com';
      final rows = [
        ['Holdings as on 06-10-2026'],
        <String>[],
        p.header,
        sampleRow(p.header, p.platform),
      ];
      final r = parser.parse(SpreadsheetLines.toText(rows), sender, receivedAt);
      expect(r.holdings, hasLength(1), reason: '${p.label}: ${r.holdings}');
      final h = r.holdings.single;
      expect(h.valueMinor, 120000, reason: p.label);
      expect(h.investedMinor, 100000, reason: p.label);
      expect(h.units, closeTo(10.0, 1e-9), reason: p.label);
      expect(h.platform, p.platform, reason: p.label);
    }
  });

  test('Zerodha Console holdings value units at the previous close', () {
    final p =
        HoldingProfiles.all.firstWhere((x) => x.label == 'Zerodha Console');
    final rows = [
      p.header,
      [
        'INFY',
        'INE009A01021',
        'IT',
        '10',
        '0',
        '10',
        '0',
        '0',
        '1500',
        '1600',
        '1000',
        '6.67',
      ],
      [
        'GOLDBEES',
        'INF204KB17I5',
        'Gold',
        '100',
        '0',
        '0',
        '0',
        '0',
        '50',
        '60',
        '1000',
        '20',
      ],
    ];
    final r = parser.parse(
      SpreadsheetLines.toText(rows),
      'Zerodha <no-reply@zerodha.com>',
      receivedAt,
    );
    final infy = r.holdings.singleWhere((x) => x.identifier == 'INE009A01021');
    expect(infy.valueMinor, 1600000);
    expect(infy.investedMinor, 1500000);
    expect(infy.kind, HoldingKind.stock);
    expect(
      r.holdings.singleWhere((x) => x.identifier == 'INF204KB17I5').kind,
      HoldingKind.gold,
    );
  });

  test('holdings mails from the investment platforms are fetched', () {
    for (final s in [
      'Your holdings statement',
      'Portfolio holdings report',
      'Holdings',
      'Mutual fund statement',
      'Balance statement as on 06 Oct',
    ]) {
      expect(ParserRegistry.isStatementSubject(s), isTrue, reason: s);
    }
    final senders = ParserRegistry.standard().defaultEmailSenders;
    for (final d in [
      'groww.in', 'zerodha.com', 'kuvera.in', 'indmoney.com', //
      'paytmmoney.com', 'etmoney.com', 'upstox.com', 'angelone.in', 'dhan.co',
      'icicidirect.com', 'hdfcsec.com', 'kotaksecurities.com',
    ]) {
      expect(senders.any((s) => s.contains(d)), isTrue, reason: d);
    }
  });
}

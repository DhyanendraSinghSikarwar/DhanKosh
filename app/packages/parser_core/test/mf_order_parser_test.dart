// Mutual fund order emails. Port of MfOrderParserTest (FR-05-24, TC-05-21).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/statement_support.dart';

void main() {
  const parser = MfOrderParser();
  final received = istMs(2026, 10, 6, 10, 15);

  test('Groww SIP instalment email gives scheme, amount, units, NAV and date',
      () {
    final body = dedent('''
      Hi A,
      Your SIP instalment of ₹5,000 for Parag Parikh Flexi Cap Fund Direct Growth has been processed successfully.
      Amount
      ₹5,000.00
      Units allotted
      61.234
      NAV
      ₹81.6543
      NAV date
      05 Oct 2026
      Folio number
      12345678/90
      Happy investing!
      Team Groww
    ''');
    final o = parser.parse(
      body,
      'Your SIP instalment for Parag Parikh Flexi Cap Fund Direct Growth is successful',
      'Groww <noreply@groww.in>',
      received,
    );
    expect(o, isNotNull);
    expect(o!.platform, 'Groww');
    expect(o.schemeName, 'Parag Parikh Flexi Cap Fund Direct Growth');
    expect(o.amountMinor, 500000);
    expect(o.units, closeTo(61.234, 0.0001));
    expect(o.nav, closeTo(81.6543, 0.00001));
    expect(o.date, const CivilDate(2026, 10, 5));
    expect(o.folio, '12345678/90');
    expect(o.isSip, isTrue);
    // Same fund as the CAS names it, so both update one holding.
    expect(
      o.identifier,
      MfOrderParser.identifierFor(
        'Parag Parikh Flexi Cap Fund - Direct Plan - Growth',
      ),
    );
  });

  test('Zerodha Coin allotment email with labelled fields', () {
    final body = dedent('''
      Hi,
      Units have been allotted for your mutual fund order.
      Fund: Axis Bluechip Fund - Direct Growth
      Folio: 91012345678
      Amount: ₹2,000.00
      Units: 45.123
      NAV: 44.3234
      Allotment date: 2026-10-05
      Team Coin by Zerodha
    ''');
    final o = parser.parse(
      body,
      'Mutual fund units allotted',
      'Coin by Zerodha <no-reply@zerodha.net>',
      received,
    )!;
    expect(o.platform, 'Zerodha Coin');
    expect(o.schemeName, 'Axis Bluechip Fund - Direct Growth');
    expect(o.amountMinor, 200000);
    expect(o.units, closeTo(45.123, 0.0001));
    expect(o.nav, closeTo(44.3234, 0.00001));
    expect(o.date, const CivilDate(2026, 10, 5));
    expect(o.folio, '91012345678');
  });

  test('KFintech confirmation sentence', () {
    const body =
        'Dear Investor, We are pleased to inform you that your SIP purchase of '
        'Rs. 3,000.00 in Mirae Asset Large Cap Fund - Direct Plan - Growth '
        'under folio 79912345678 has been processed at NAV of Rs. 110.4521 on '
        '06/10/2026 and 27.161 units have been allotted.';
    final o = parser.parse(
      body,
      'Transaction confirmation - Mirae Asset Mutual Fund',
      'KFintech <noreply@kfintech.com>',
      received,
    )!;
    expect(o.platform, 'KFintech');
    expect(o.schemeName, 'Mirae Asset Large Cap Fund - Direct Plan - Growth');
    expect(o.amountMinor, 300000);
    expect(o.units, closeTo(27.161, 0.0001));
    expect(o.nav, closeTo(110.4521, 0.00001));
    expect(o.date, const CivilDate(2026, 10, 6));
  });

  test('order placed before units are allotted still gives the amount', () {
    const body =
        'Your order of ₹10,000 in HDFC Index Fund Nifty 50 Plan Direct Growth '
        'was placed successfully. Units will be allotted in 2-3 working days.';
    final o = parser.parse(
      body,
      'Order successful',
      'Groww <noreply@groww.in>',
      received,
    )!;
    expect(o.schemeName, 'HDFC Index Fund Nifty 50 Plan Direct Growth');
    expect(o.amountMinor, 1000000);
    expect(o.units, isNull);
    expect(o.date, const CivilDate(2026, 10, 6));
  });

  test('amount falls back to units x NAV; far dates fall back to received', () {
    final o = parser.parse(
      'Units have been allotted.\nFund: Axis Bluechip Fund - Direct Growth\n'
          'Units: 10.000\nNAV: 50.00\nAllotment date: 2020-01-05',
      'Mutual fund units allotted',
      'CAMS <donotreply@camsonline.com>',
      received,
    )!;
    expect(o.amountMinor, 50000);
    expect(o.date, const CivilDate(2026, 10, 6));
    expect(o.platform, 'CAMS');
  });

  test('reminders, failures and redemptions are not purchases', () {
    expect(
      parser.parse(
        'Your SIP of ₹5,000 for Parag Parikh Flexi Cap Fund Direct Growth is '
            'due on 10 Oct 2026. Keep sufficient balance.',
        'SIP reminder',
        'Groww <noreply@groww.in>',
        received,
      ),
      isNull,
    );
    expect(
      parser.parse(
        'Your SIP instalment of ₹5,000 for Parag Parikh Flexi Cap Fund Direct '
            'Growth failed due to insufficient balance.',
        'SIP failed',
        'Groww <noreply@groww.in>',
        received,
      ),
      isNull,
    );
    expect(
      parser.parse(
        'Your redemption of 10.000 units of Axis Bluechip Fund - Direct Growth '
            'has been processed. Amount ₹520.00 will be credited.',
        'Redemption processed',
        'Coin by Zerodha <no-reply@zerodha.net>',
        received,
      ),
      isNull,
    );
  });

  test('scheme names normalise across apps and statements', () {
    expect(
      MfOrderParser.identifierFor(
        'Parag Parikh Flexi Cap Fund - Direct Plan - Growth',
      ),
      'MF:parag parikh flexi cap',
    );
    expect(
      MfOrderParser.identifierFor('PARAG PARIKH FLEXI CAP FUND DIRECT GROWTH'),
      'MF:parag parikh flexi cap',
    );
    expect(
      MfOrderParser.identifierFor('HDFC Index Fund-NIFTY 50 Plan-Direct Plan'),
      'MF:hdfc index nifty 50',
    );
  });

  test('parseMfOrder is the same as MfOrderParser.parse', () {
    expect(
      parseMfOrder(
        'Your order of ₹10,000 in HDFC Index Fund Nifty 50 Plan Direct Growth '
            'was placed successfully.',
        'Order successful',
        'Groww <noreply@groww.in>',
        received,
      )?.amountMinor,
      1000000,
    );
  });
}

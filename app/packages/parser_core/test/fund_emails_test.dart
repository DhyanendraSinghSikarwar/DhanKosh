// Fund and investment emails through the public parsers: SIP and order
// confirmations (Groww, INDmoney), INDmoney's portfolio summary, EPFO and NPS
// emails. Port of FundEmailsTest (FR-05-16, FR-05-23, FR-05-25, TC-05-14,
// TC-05-22).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';
import 'support/statement_support.dart';

void main() {
  final at = receivedAt;
  const orders = MfOrderParser();

  test('Groww SIP email and a CAS row for the same fund share one holding key',
      () {
    final o = orders.parse(
      'Your SIP instalment of ₹5,000 for Parag Parikh Flexi Cap Fund Direct '
          'Growth has been processed successfully.\n'
          'Units allotted 61.234\nNAV ₹81.6543\nNAV date 23 Sep 2026',
      'SIP instalment processed',
      'Groww <noreply@groww.in>',
      at,
    )!;
    expect(o.amountMinor, 500000);
    expect(o.date, const CivilDate(2026, 9, 23));
    expect(
      o.identifier,
      MfOrderParser.identifierFor(
        'Parag Parikh Flexi Cap Fund - Direct Plan - Growth',
      ),
    );
    expect(o.isSip, isTrue);
    expect(o.units, closeTo(61.234, 1e-9));
  });

  test('INDmoney mutual fund order email', () {
    final o = orders.parse(
      dedent('''
        Hi A,
        Your mutual fund order has been placed successfully.
        Fund Name: Axis Small Cap Fund Direct Growth
        Amount: ₹10,000.00
        Order date: 22 Sep 2026
        Units will be allotted at the applicable NAV.
        Team INDmoney
      '''),
      'Order successful',
      'INDmoney <noreply@indmoney.com>',
      at,
    );
    expect(o, isNotNull);
    expect(o!.platform, 'INDmoney');
    expect(o.schemeName, 'Axis Small Cap Fund Direct Growth');
    expect(o.amountMinor, 1000000);
    expect(o.date, const CivilDate(2026, 9, 22));
  });

  test('failed SIP is not a purchase', () {
    expect(
      orders.parse(
        'Your SIP instalment for Axis Small Cap Fund Direct Growth has failed '
            'due to insufficient balance.',
        'SIP failed',
        'Groww <noreply@groww.in>',
        at,
      ),
      isNull,
    );
  });

  test('INDmoney portfolio summary table gives one aggregate per class', () {
    final text = dedent('''
      Hi A, here is your weekly portfolio summary as on 24 Sep 2026.
      Asset Invested Current Value Returns
      Mutual Funds ₹1,20,000 ₹1,35,400 +12.83%
      US Stocks ₹50,000 ₹58,200 +16.40%
      Indian Stocks ₹80,000 ₹76,500 -4.38%
      Total ₹2,50,000 ₹2,70,100
      Team INDmoney
    ''');
    final hs = {
      for (final h in PortfolioSummary.parse(
        text,
        'Your weekly portfolio summary',
        'INDmoney <updates@indmoney.com>',
        at,
      ))
        h.identifier: h,
    };
    expect(
      hs.keys.toSet(),
      {'AGG:INDMONEY:MF', 'AGG:INDMONEY:US', 'AGG:INDMONEY:STOCKS'},
    );
    final mf = hs['AGG:INDMONEY:MF']!;
    expect(mf.kind, HoldingKind.mutualFund);
    expect(mf.investedMinor, 12000000);
    expect(mf.valueMinor, 13540000);
    expect(hs['AGG:INDMONEY:US']!.valueMinor, 5820000);
    expect(hs['AGG:INDMONEY:STOCKS']!.investedMinor, 8000000);
    expect(hs['AGG:INDMONEY:STOCKS']!.valueMinor, 7650000);
  });

  test('INDmoney summary with labelled figures on separate lines', () {
    final text = dedent('''
      Your monthly portfolio update
      Mutual Funds
      Current: ₹1,35,400
      Invested: ₹1,20,000
      US Stocks
      Current: ₹58,200
      Invested: ₹50,000
    ''');
    final hs = {
      for (final h in parsePortfolioSummary(
        text,
        null,
        'INDmoney <updates@indmoney.com>',
        at,
      ))
        h.identifier: h,
    };
    expect(hs['AGG:INDMONEY:MF']!.valueMinor, 13540000);
    expect(hs['AGG:INDMONEY:MF']!.investedMinor, 12000000);
    expect(hs['AGG:INDMONEY:US']!.investedMinor, 5000000);
  });

  test('an email that is not an INDmoney summary gives nothing', () {
    expect(
      PortfolioSummary.parse(
        'Mutual Funds ₹1,20,000 ₹1,35,400',
        'Weekly portfolio summary',
        'Groww <noreply@groww.in>',
        at,
      ),
      isEmpty,
    );
    expect(
      PortfolioSummary.parse(
        'Your US Stocks order of ₹5,000 is placed',
        'Order placed',
        'INDmoney <noreply@indmoney.com>',
        at,
      ),
      isEmpty,
    );
  });

  test('EPFO passbook email updates the EPF holding by member id', () {
    final h = InvestmentParser.parseEmail(
      'Dear Member, your passbook balance against MH/BAN/0012345/000/0001234 '
      'is Rs. 2,56,250/-. Contribution of Rs. 3,600/- for due month 092026 '
      'has been received.',
      at,
    )!;
    expect(h.kind, HoldingKind.epf);
    expect(h.identifier, 'EPF:MHBAN00123450000001234');
    expect(h.valueMinor, 25625000);
    expect(h.contributionMinor, 360000);
  });

  test('NPS emails give the contribution and the holding value', () {
    final c = InvestmentParser.npsContribution(
      'Dear Subscriber, Contribution of Rs.5000.00 for PRAN XXXXXXXX1234 has '
      'been credited to your Tier I account on 22-09-2026. -NPS CRA',
      at,
    )!;
    expect(c.identifier, 'NPS:1234');
    expect(c.amountMinor, 500000);
    final v = InvestmentParser.parseEmail(
      'Your NPS a/c PRAN XXXXXXXX1234 holding value as on 23-09-2026 is Rs. '
      '4,56,789.12.',
      at,
    )!;
    expect(v.kind, HoldingKind.nps);
    expect(v.identifier, 'NPS:1234');
    expect(v.valueMinor, 45678912);
  });
}

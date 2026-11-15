// Outgoing NEFT to a beneficiary, and the incoming NEFT told by an SMS and a
// statement (FR-06-28, FR-07-24). Every text is synthetic.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  final registry = ParserRegistry.standard();
  final at = DateTime.utc(2026, 11).millisecondsSinceEpoch;

  test(
      '"credited to beneficiary X, A/c XX3967" is a payment out, not the '
      "user's account", () {
    final t = registry.parse(
      'Your NEFT txn with Ref. No. AXOMB26502128070 for INR 22000.00 is '
          'credited to beneficiary Parag Agrawal, A/c no. XX3967 on 22-09-26 at '
          '20:32:36 IST - Axis Bank',
      'JX-AXISBK-S',
      at,
      Source.sms,
    )!;
    expect(t.type, TransactionType.debit);
    expect(t.accountLast4, isNull);
    expect(t.counterpartyLast4, '3967');
    expect(t.merchant, 'Parag Agrawal');
    expect(t.referenceNumber, 'AXOMB26502128070');
  });

  test('incoming NEFT SMS names the sender, not the link text', () {
    final t = registry.parse(
      'INR 26360.00 credited to Axis Bank A/c XX5602 on 30-10-26 at 18:07:52 '
          'IST. Ref: NEFT/SCBLH30301640629/ROYA.View bal: https://x.example/ab',
      'JD-AXISBK-S',
      at,
      Source.sms,
    )!;
    expect(t.type, TransactionType.credit);
    expect(t.accountLast4, '5602');
    expect(t.merchant, 'Roya');
    expect(t.referenceNumber, 'SCBLH30301640629');
  });

  test('a statement reads the account from its "Account No" line', () {
    final r = const StatementParser().parse(
      'AXIS BANK\nStatement of Account\nAccount No : 920010045605602\n'
          'Registered Mobile XXXXXX6810\n'
          '30-10-2026 NEFT/SCBLH30301640629/ROYAL SUNDARAM GENERAL INSUR '
          '26,360.00 8,647.46\n',
      'AXIS BANK Statement for October 2026.pdf',
      at,
    );
    expect(r.bankName, 'Axis Bank');
    expect(r.last4, '5602');
    expect(r.transactions.single.referenceNumber, 'SCBLH30301640629');
  });

  test('a masked mobile number is never the statement account', () {
    final r = const StatementParser().parse(
      'AXIS BANK\nStatement of Account\nRegistered Mobile XXXXXX6810\n'
          '30-10-2026 NEFT/SCBLH30301640629/ROYAL SUNDARAM GENERAL INSUR '
          '26,360.00 8,647.46\n',
      'AXIS BANK Statement for October 2026.pdf',
      at,
    );
    expect(r.last4, isNull);
  });
}

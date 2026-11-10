// The other party's account in a bank message (FR-13-25). Synthetic texts.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  final registry = ParserRegistry.standard();
  final at = DateTime.utc(2026, 11, 7, 10).millisecondsSinceEpoch;

  ParsedTransaction read(String sender, String body) =>
      registry.parse(body, sender, at, Source.sms)!;

  test('debit to another account names it as the counterparty', () {
    final t = read(
      'VM-HDFCBK-S',
      'Rs 5,000.00 debited from a/c XX1234 on 07-11-26 and credited to '
          'a/c XX5678. IMPS Ref 612345678901. Avl bal Rs 9,000.',
    );
    expect(t.accountLast4, '1234');
    expect(t.counterpartyLast4, '5678');
  });

  test('credit from another account names it too', () {
    final t = read(
      'VM-ICICIB-S',
      'Rs 5,000.00 credited to A/c XX5678 on 07-11-26 from A/c XX1234. '
          'IMPS Ref 612345678901.',
    );
    expect(t.accountLast4, '5678');
    expect(t.counterpartyLast4, '1234');
  });

  test('an ordinary shop payment has no counterparty account', () {
    final t = read(
      'VM-HDFCBK-S',
      'Rs 250.00 debited from a/c XX1234 on 07-11-26 to SWIGGY. UPI Ref '
          '612345678901.',
    );
    expect(t.counterpartyLast4, isNull);
  });
}

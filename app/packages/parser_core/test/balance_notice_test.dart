// A balance-only message names an account and a figure (FR-06-27).
// Every text is synthetic.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  final registry = ParserRegistry.standard();
  final at = DateTime.utc(2026, 11, 7, 10).millisecondsSinceEpoch;

  test('available balance message gives bank, account and figure', () {
    final n = registry.balanceNotice(
      'Your available balance in account ending XX5152 is Rs. 1,155.70 as on '
          '07-NOV-26',
      'VM-HDFCBK-S',
      at,
    );
    expect(n, isNotNull);
    expect(n!.bank, 'HDFC Bank');
    expect(n.last4, '5152');
    expect(n.balanceMinor, 115570);
  });

  test('a payment message is not a balance notice', () {
    expect(
      registry.balanceNotice(
        'Rs 650.00 debited from a/c XX1234 on 07-11-26. Avl bal is Rs 100.',
        'VM-HDFCBK-S',
        at,
      ),
      isNull,
    );
  });

  test('an unknown sender is ignored', () {
    expect(
      registry.balanceNotice(
        'Your available balance in account ending XX5152 is Rs. 10.00',
        'AB-RANDOM',
        at,
      ),
      isNull,
    );
  });
}

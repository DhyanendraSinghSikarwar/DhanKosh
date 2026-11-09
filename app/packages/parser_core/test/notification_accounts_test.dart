// Which card or account a payment-app notification names, and the balance or
// limit it states (FR-04-25). Every text is synthetic.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  const reader = FreeTextParser();
  final at = DateTime.utc(2026, 11, 7, 10).millisecondsSinceEpoch;

  ParsedTransaction read(String app, String text) {
    final r = reader.readNotification(app, [text], at);
    expect(r.tx, isNotNull, reason: '$text -> ${r.skipReason}');
    return r.tx!;
  }

  test('paid to a shop using a credit card is a spend on that card', () {
    final t = read(
      'PhonePe',
      'Paid ₹250 to Swiggy using SBI Credit Card ending 1234',
    );
    expect(t.type, TransactionType.debit);
    expect(t.merchant, 'Swiggy');
    expect(t.accountKind, AccountKind.card);
    expect(t.accountLast4, '1234');
    expect(t.bankName, 'SBI');
  });

  test('paid to the card itself is still a card bill', () {
    final t = read('PhonePe', 'Paid ₹6,774 to Axis Bank Credit Card');
    expect(t.type, TransactionType.transfer);
  });

  test('a masked number with bullets names the account', () {
    final t = read(
      'Google Pay',
      'You paid ₹120 to Zepto. Paid from Axis Bank ••4321',
    );
    expect(t.accountLast4, '4321');
    expect(t.accountKind, AccountKind.account);
  });

  test('a stated available limit or balance travels with the payment', () {
    final card = read(
      'SBI YONO',
      'Rs.1,200.00 spent on your SBI Credit Card ending 7711 at AMAZON. '
          'Available limit Rs.40,000',
    );
    expect(card.availableLimitMinor, 4000000);
    final bank = read(
      'PhonePe',
      'Sent ₹300 to Madhuri Sharma. Debited from HDFC Bank XX2210. '
          'Avl Bal Rs.12,500.00',
    );
    expect(bank.balanceMinor, 1250000);
    expect(bank.accountLast4, '2210');
  });
}

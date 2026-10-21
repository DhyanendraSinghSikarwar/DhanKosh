// Payment-app notifications: the amount is the payment, never a balance, offer
// or call to pay; the bank is read only when named. Port of
// PaymentAppAmountsTest (FR-06-16).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  const parser = FreeTextParser();
  const at = 1790000000000;

  ParsedTransaction? read(List<String> parts) =>
      parser.readNotification('PhonePe', parts, at).tx;

  test('balance line before the payment is not the amount', () {
    final tx = read(['Avl bal Rs 5,000', 'Paid ₹250 to Ravi Kumar']);
    expect(tx!.amountMinor, 25000);
  });

  test('balance clause in the same sentence is cut off', () {
    expect(
      read(['₹250 debited, Avl Bal ₹4,750', 'to Ravi Kumar'])!.amountMinor,
      25000,
    );
  });

  test('rupees off promo next to a payment is ignored', () {
    final tx =
        read(['Paid ₹250 to Ravi Kumar', 'Get ₹10 off on your next payment']);
    expect(tx!.amountMinor, 25000);
    expect(tx.merchant, 'Ravi Kumar');
  });

  test(
      'pay now promo with an amount is not a payment and does not hide '
      'one', () {
    expect(read(['Pay now ₹1,299', 'Your plan renews soon']), isNull);
    expect(
      read(['Paid ₹250 to Ravi Kumar', 'Pay now ₹1,299 and get rewards'])!
          .amountMinor,
      25000,
    );
  });

  test('cashback line is not the payment', () {
    expect(
      read(['₹5 cashback received', 'Paid ₹250 to Ravi Kumar'])!.amountMinor,
      25000,
    );
    expect(read(['You got ₹5 cashback']), isNull);
  });

  test('bank and last 4 are read only when the notification names them', () {
    final named =
        read(['Payment successful', '₹320 debited from HDFC Bank A/c XX1234'])!;
    expect(named.bankName, 'HDFC Bank');
    expect(named.accountLast4, '1234');
    final plain = read(['Paid ₹250 to Ravi Kumar'])!;
    expect(plain.accountLast4, isNull);
    expect(plain.bankName, 'PhonePe');
  });

  test('a card named in the notification is a card', () {
    final tx =
        read(['Paid ₹450 to Swiggy', 'via Axis Bank Credit Card XX0775'])!;
    expect(tx.bankName, 'Axis Bank');
    expect(tx.accountLast4, '0775');
    expect(tx.accountKind, AccountKind.card);
    expect(tx.merchant, isNotNull);
  });
}

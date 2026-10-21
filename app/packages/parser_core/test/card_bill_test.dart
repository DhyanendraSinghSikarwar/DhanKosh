// Paying a credit card's bill is a transfer: neither a spend nor income. Spends
// on the card and payments to others stay as they are. Port of CardBillTest
// (FR-06-10, AC-06-04).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

void main() {
  final registry = ParserRegistry.standard();
  const free = FreeTextParser();

  ParsedTransaction? sms(String sender, String body) =>
      registry.parse(body, sender, receivedAt, Source.sms);

  void assertBill(String body, [String sender = 'VM-HDFCBK']) {
    final tx = sms(sender, body);
    expect(tx, isNotNull, reason: body);
    expect(tx!.type, TransactionType.transfer, reason: body);
    expect(tx.category, Category.transfer, reason: body);
    expect(tx.amountMinor, 677464, reason: body);
  }

  void assertSpend(String body, [String sender = 'VM-HDFCBK']) {
    final tx = sms(sender, body);
    expect(tx, isNotNull, reason: body);
    expect(tx!.type, TransactionType.debit, reason: body);
    expect(tx.category, isNot(Category.transfer), reason: body);
  }

  test('bank debit towards a card is a bill payment', () {
    assertBill(
      'Rs.6,774.64 debited from A/c XX1234 on 10-10-26 towards Axis Bank '
      'Credit Card XX0775. Avl bal Rs.20,000.00',
    );
    assertBill(
      'Rs.6,774.64 debited from A/c XX1234 on 10-10-26 towards your HDFC Bank '
      'Credit Card XX5678. Avl bal Rs.20,000.00',
    );
    assertBill(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: CC BILL '
      'PAYMENT. Avl bal:INR 20,000.00',
    );
    assertBill(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: HDFC CC '
      'payment. Avl bal:INR 20,000.00',
    );
    assertBill(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: SBI Card '
      'payment. Avl bal:INR 20,000.00',
    );
    assertBill(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: '
      'UPI-ICICI CREDIT CARD-icicicc@icici. Avl bal:INR 20,000.00',
    );
  });

  test(
      'bank debit through a bill collector or issuer name is a bill '
      'payment', () {
    assertBill(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: '
      'UPI-AXIS BANK CREDIT CARD-cc.axis@axisbank. Avl bal:INR 20,000.00',
    );
    assertBill(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: '
      'UPI-AXISCC-axiscc@axisbank. Avl bal:INR 20,000.00',
    );
    assertBill(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: '
      'UPI-CRED CLUB-cred.club@axisb. Avl bal:INR 20,000.00',
    );
    assertBill(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: '
      'BILLDESK-CC. Avl bal:INR 20,000.00',
    );
    assertBill(
      'Rs.6,774.64 debited from A/c XX1234 on 10-10-26 via IMPS to AXIS BANK '
      'LTD CARD Ref 526812340032. Avl bal Rs.20,000.00',
    );
  });

  test('card side payment received is a transfer, never income', () {
    final tx = sms(
      'AX-AXISBK',
      'Payment of Rs 6,774.64 received towards your Axis Bank Credit Card '
          'XX0775 on 12-10-26. Thank you.',
    )!;
    expect(tx.type, TransactionType.transfer);
    expect(tx.accountKind, AccountKind.card);
    expect(tx.category, Category.transfer);
    final posted = sms(
      'AX-AXISBK',
      'Rs 6,774.64 payment credited to your Axis Bank Credit Card XX0775 on '
          '12-10-26. Avl limit Rs 90,000.00',
    );
    if (posted != null) expect(posted.type, TransactionType.transfer);
  });

  test('net banking email of a card bill payment is a transfer', () {
    final tx = registry.parse(
      'Dear Customer,\n\nCredit card bill payment successful. Rs.6,774.64 has '
          'been debited from your account XX1234 towards credit card XX0775 on '
          '10-10-26.\n\nWarm Regards,\nHDFC Bank',
      'HDFC Bank InstaAlerts <alerts@hdfcbank.net>',
      receivedAt,
      Source.email,
    );
    expect(tx, isNotNull);
    expect(tx!.type, TransactionType.transfer);
    expect(tx.category, Category.transfer);
  });

  test('payment app notifications that pay a card are kept as transfers', () {
    for (final (app, title, body) in [
      ('PhonePe', 'Paid ₹6,774', 'to Axis Bank Credit Card'),
      (
        'Google Pay',
        'Payment successful',
        '₹6,774 paid to Axis Bank Credit Card'
      ),
      ('Paytm', 'Payment successful', 'Paid ₹6,774 to cc.axis@axisbank'),
      ('Amazon Pay', 'Paid ₹6,774', 'to HDFC Bank Credit Card'),
      (
        'MobiKwik',
        'Payment successful',
        '₹6,774 paid towards your ICICI Credit Card',
      ),
      (
        'CRED',
        'Credit card bill paid',
        '₹6,774 paid towards your HDFC Bank Credit Card',
      ),
    ]) {
      final tx = free.fromNotification(app, title, body, 1760000000000);
      final why = '$app $title $body';
      expect(tx, isNotNull, reason: why);
      expect(tx!.type, TransactionType.transfer, reason: why);
      expect(tx.category, Category.transfer, reason: why);
      expect(tx.amountMinor, 677400);
    }
  });

  test('payments to others and spends on a card are never bills', () {
    assertSpend(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: '
      'UPI-AXIS GOLD-axisgold@ybl. Avl bal:INR 20,000.00',
    );
    assertSpend(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: '
      'UPI-CREDIT BAZAAR-creditbazaar@ybl. Avl bal:INR 20,000.00',
    );
    assertSpend(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: '
      'UPI-CRED CASHBACK STORE-credstore@axisb. Avl bal:INR 20,000.00',
    );
    assertSpend(
      'INR 6,774.64 debited from HDFC Bank XX1234 on 10-OCT-26. Info: '
      'UPI-CC SHARMA-cc.sharma@okaxis. Avl bal:INR 20,000.00',
    );
    final card = sms(
      'VM-HDFCBK',
      'Rs.6,774.64 spent via HDFC Bank Card xx5678 at AXIS GOLD on '
          '2026-09-20:22:01:45 Avl Lmt: Rs 1,23,456.00',
    )!;
    expect(card.type, TransactionType.debit);
    expect(card.category, isNot(Category.transfer));
    final notif = free.fromNotification(
      'PhonePe',
      'Paid ₹6,774',
      'to Credit Bazaar',
      1760000000000,
    )!;
    expect(notif.type, TransactionType.debit);
  });

  test('payee rules match cards and issuers only', () {
    expect(CardBill.isPayee('Axis Bank Credit Card', null), isTrue);
    expect(CardBill.isPayee('Credit Card Bill Payment', null), isTrue);
    expect(CardBill.isPayee('HDFCCC', null), isTrue);
    expect(CardBill.isPayee('SBI Card', null), isTrue);
    expect(CardBill.isPayee('Cred', null), isTrue);
    expect(CardBill.isPayee(null, 'cc.axis@axisbank'), isTrue);
    expect(CardBill.isPayee(null, 'icicicc1234@icici'), isTrue);
    expect(CardBill.isPayee(null, 'cardpayment@hdfcbank'), isTrue);
    expect(CardBill.isPayee('Axis Gold', null), isFalse);
    expect(CardBill.isPayee('Credit Bazaar', null), isFalse);
    expect(CardBill.isPayee('Credit Card Cafe', null), isFalse);
    expect(CardBill.isPayee('CRED Cashback Store', 'credstore@axisb'), isFalse);
    expect(CardBill.isPayee('Ravi Kumar', 'cc.sharma@okaxis'), isFalse);
  });

  test('a card cannot pay its own bill, so card debits are never marked', () {
    final card = sms(
      'VM-HDFCBK',
      'Rs.499.00 spent via HDFC Bank Card xx5678 at CREDIT CARD CAFE on '
          '2026-09-20:22:01:45 Avl Lmt: Rs 1,23,456.00',
    )!;
    expect(CardBill.mark(card, 'payment').type, TransactionType.debit);
  });

  test(
      'mark turns a plain debit to a card into a transfer and is '
      'idempotent', () {
    final plain = sms(
      'VM-HDFCBK',
      'INR 1,200.00 debited from HDFC Bank XX1234 on 10-OCT-26. '
          'Info: UPI-RAVI-ravi@ybl. Avl bal:INR 20,000.00',
    )!;
    expect(plain.type, TransactionType.debit);
    final typed = plain.copyWith(
      merchant: 'HDFC Credit Card',
      source: Source.manual,
      category: Category.bills,
    );
    final once = CardBill.mark(typed, null);
    expect(once.type, TransactionType.transfer);
    expect(once.category, Category.transfer);
    expect(CardBill.mark(once, null), once);
    expect(CardBill.mark(plain, 'paid to ravi').type, TransactionType.debit);
  });

  test('the label is the default merchant of a marked bill', () {
    final plain = sms(
      'VM-HDFCBK',
      'Rs.6,774.64 debited from A/c XX1234 on 10-10-26 via IMPS Ref '
          '526812340033. Avl bal Rs.20,000.00',
    )!;
    final marked = CardBill.mark(plain, 'credit card bill payment');
    expect(marked.type, TransactionType.transfer);
    expect(marked.merchant, plain.merchant ?? CardBill.label);
  });
}

// Payee and payer names that used to be missed or garbled (FR-06-24).
// Every message is synthetic.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  final registry = ParserRegistry.standard();
  final at = DateTime.utc(2026, 11, 7, 10).millisecondsSinceEpoch;

  ParsedTransaction read(String sender, String body) {
    final tx = registry.parse(body, sender, at, Source.sms);
    expect(tx, isNotNull, reason: body);
    return tx!;
  }

  test('a title before the name is dropped, the name kept', () {
    expect(
      read(
        'VM-HDFCBK-S',
        'Rs 650.00 debited from a/c XX1234 on 07-11-26 to MR. RAVI KUMAR '
            'SHARMA. UPI Ref 612345678901.',
      ).merchant,
      'Ravi Kumar Sharma',
    );
    expect(
      read(
        'VM-SBIUPI-S',
        'Dear UPI user A/C X1234 debited by 150.0 on date 07Nov26 trf to Mr '
            'Ramesh Refno 612345678901. If not u? call 1800111109',
      ).merchant,
      'Ramesh',
    );
  });

  test('"Payee: M/S SHARMA & SONS" is read as a firm name', () {
    expect(
      read(
        'VM-ICICIB-S',
        'ICICI Bank Acct XX123 debited with Rs 410.00 on 07-Nov-26 & Acct '
            'XX999 credited. IMPS Ref 612345678901. Payee: M/S SHARMA & SONS.',
      ).merchant,
      'Sharma & Sons',
    );
  });

  test('"Merchant: ..." and "Beneficiary NAME" labels', () {
    expect(
      read(
        'VM-PNBSMS-S',
        'A/c 1234 debited INR 640.00 Dt 07-11-26 Merchant: Uber India '
            'Systems. Avl bal 100.',
      ).merchant,
      'Uber',
    );
    final t = read(
      'VM-HDFCBK-S',
      'Money Transfer:Rs 2,500.00 from HDFC Bank A/c XX1234 to Beneficiary '
          'SUNITA DEVI on 07-11-26. Ref 612345678901.',
    );
    expect(t.merchant, 'Sunita Devi');
    expect(t.type, TransactionType.debit);
  });

  test('"Dr. to ZEPTO" has a direction and a name', () {
    final t = read(
      'VM-BOBTXN-S',
      'Rs.120.00 Dr. to ZEPTO via UPI on 07-11-26 Ref No 612345678901. BOB',
    );
    expect(t.type, TransactionType.debit);
    expect(t.merchant, 'Zepto');
  });

  test('a UPI id is not glued to the reference and name before it', () {
    final t = read(
      'VM-YESBNK-S',
      'Rs.88.00 debited A/c XX1234 on 07/11/26 for '
          'UPI-612345678901-BIGBASKET-bigbasket@icici-Payment.',
    );
    expect(t.upiId, 'bigbasket@icici');
    expect(t.merchant, 'BigBasket');
  });
}

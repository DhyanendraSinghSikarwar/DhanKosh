// Indian senders added from the PennyWise comparison (FR-06-26, issue I-07).
// Every message is synthetic: made-up amounts, accounts and references.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  final registry = ParserRegistry.standard();
  final at = DateTime.utc(2026, 11, 3, 10).millisecondsSinceEpoch;

  ParsedTransaction? read(String sender, String body) =>
      registry.parse(body, sender, at, Source.sms);

  group('headers that used to be dropped are now known', () {
    const expected = {
      'IPBMSG': 'India Post Payments Bank',
      'JIOPBS': 'Jio Payments Bank',
      'NSDLPB': 'Jio Payments Bank',
      'UTKSPR': 'Utkarsh Small Finance Bank',
      'BDNSMS': 'Bandhan Bank',
      'FEDFIB': 'Federal Bank',
      'FEDSCP': 'Federal Bank',
      'PNBCCD': 'Punjab National Bank',
      'CUBLTD': 'City Union Bank',
      'JKBNK': 'Jammu & Kashmir Bank',
      'SSFBNK': 'Suryoday Small Finance Bank',
      'KBLBNK': 'Karnataka Bank',
      'KGBANK': 'Kerala Gramin Bank',
      'KELBNK': 'Kerala Bank',
      'GRTRBN': 'Greater Bank',
      'DOPBNK': 'Post Office Savings Bank',
      'JTEDGE': 'Jupiter (CSB Bank)',
      'ONECRD': 'OneCard',
      'AMEXIN': 'American Express',
      'SLCEIT': 'slice',
    };
    for (final e in expected.entries) {
      test(e.key, () {
        final p = registry.resolve('VM-${e.key}-S');
        expect(p, isNotNull);
        expect(p!.bankName, e.value);
      });
    }
    test('CREDIN is read as the CRED app', () {
      expect(registry.isKnownSender('AX-CREDIN-S'), isTrue);
    });
    test('JioPay wallet is no longer a Jio Payments Bank account', () {
      expect(
        registry.resolve('JA-JIOPAY-S')?.bankName,
        isNot('Jio Payments Bank'),
      );
    });
  });

  group('messages from them', () {
    test('Greater Bank "had a CREDIT transaction" is money in', () {
      final tx = read(
        'VM-GRTRBN-S',
        'Dear Customer, your A/c XXXX5521 had a CREDIT transaction of '
            'Rs.2,500.00 on 03-11-2026. Available balance Rs.12,400.00.',
      );
      expect(tx?.type, TransactionType.credit);
      expect(tx?.amountMinor, 250000);
    });

    test('Greater Bank "had a DEBIT transaction" is money out', () {
      final tx = read(
        'VM-GRTRBN-T',
        'Dear Customer, your A/c XXXX5521 had a DEBIT transaction of '
            'Rs.600.00 on 03-11-2026. Available balance Rs.11,800.00.',
      );
      expect(tx?.type, TransactionType.debit);
    });

    test('a loan-recovery credit is a repayment, not income', () {
      final tx = read(
        'AX-KELBNK-S',
        'Rs 4500.00 credited to your A/c XX7712 on 03-Nov-26 by Loan '
            'Recovery. Bal 1,25,000.00',
      );
      expect(tx?.type, TransactionType.transfer);
    });

    test('Amex "a charge of ... was made" is a card spend', () {
      final tx = read(
        'AX-AMEXIN-S',
        'A charge of INR 1,250.00 was made on your American Express Card '
            'ending 31005 at AMAZON on 3 November 2026.',
      );
      expect(tx?.type, TransactionType.debit);
      expect(tx?.accountKind, AccountKind.card);
      expect(tx?.amountMinor, 125000);
    });

    test('OneCard "fuel spend of" is a card spend', () {
      final tx = read(
        'AX-ONECRD-S',
        'Fuel spend of Rs.1,800.00 on your OneCard ending 7711 at INDIAN '
            'OIL on 03-Nov-2026.',
      );
      expect(tx?.type, TransactionType.debit);
      expect(tx?.bankName, 'OneCard');
    });

    test('India Post Payments Bank under its new header', () {
      final tx = read(
        'JD-IPBMSG-S',
        'A/c X1234 debited by Rs.100.00 on 03-11-26 trf to ABC Ref '
            '612345678901. Avl Bal Rs.900.00',
      );
      expect(tx?.bankName, 'India Post Payments Bank');
      expect(tx?.accountLast4, '1234');
    });

    test('Jupiter card spend', () {
      final tx = read(
        'JD-JTEDGE-S',
        'Rs.499.00 spent on your Edge CSB RuPay Credit Card XX4321 at '
            'ZOMATO on 03-11-2026. Available limit Rs.40,000.00',
      );
      expect(tx?.accountKind, AccountKind.card);
      expect(tx?.accountLast4, '4321');
    });
  });
}

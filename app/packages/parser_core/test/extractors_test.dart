// Port of ExtractorsTest (FR-06-07).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

String n(String s) => TextNormalizer.normalize(s);

void main() {
  test('amount skips balance and limit figures', () {
    expect(
      AmountExtractor.extract(
        n('Avl Bal Rs 9,999.00. Rs.250.00 debited from A/c XX1234'),
      ),
      const Money(25000, 'INR'),
    );
    expect(
      AmountExtractor.extract(
        n('Rs 1,23,456.50 credited. Avl bal:INR 2,00,000.00'),
      ),
      const Money(12345650, 'INR'),
    );
    expect(
      AmountExtractor.extract('USD 12.00 spent on Card XX1234 at NETFLIX.COM'),
      const Money(1200, 'USD'),
    );
  });

  test('amount without a currency after debited by', () {
    expect(
      AmountExtractor.extract('A/C X1234 debited by 3,000.0 on date 05Sep26'),
      const Money(300000, 'INR'),
    );
  });

  test('money rejects zero and nonsense', () {
    expect(Money.parse('0.00'), isNull);
    expect(Money.parse(','), isNull);
    expect(Money.parse('0.5')!.minor, 50);
  });

  test('money parses decimal text exactly, with the ceiling (TC-06-07)', () {
    expect(Money.parse('1,23,456.5')!.minor, 12345650);
    expect(Money.parse('12345678901234.00'), isNull);
    expect(Money.parse('10000000000.00')!.minor, 1000000000000);
    expect(Money.parse('10000000000.01'), isNull);
    expect(Money.parse('0.125')!.minor, 13); // half up
    expect(Money.parse('19.99')!.minor, 1999);
    expect(Money.parse('5.')!.minor, 500);
    expect(Money.parseSigned('-500.00'), -50000);
    expect(Money.parseSigned('0.00'), 0);
  });

  test('balance and limit', () {
    expect(BalanceExtractor.balance(n('Avl bal:INR 10,450.00')), 1045000);
    expect(
      BalanceExtractor.balance(n('AvlBal:Rs12090.50(2026:09:25)')),
      1209050,
    );
    expect(
      BalanceExtractor.balance(n('Available Balance is INR -500.00')),
      -50000,
    );
    expect(BalanceExtractor.limit(n('Avl Lmt INR 48,501.00')), 4850100);
  });

  group('account last digits and kind', () {
    const rows = [
      ('A/c XX1234 debited', '1234', AccountKind.account),
      ('a/c no. XXXXXX1234 debited', '1234', AccountKind.account),
      ('Acct XX123 debited', '123', AccountKind.account),
      ('from A/C *1234 to', '1234', AccountKind.account),
      ('Card x5678 at', '5678', AccountKind.card),
      ('Credit Card ending 5678 for', '5678', AccountKind.card),
      ('Credit Card Account 4xxx xxxx xxxx 9012 on', '9012', AccountKind.card),
      ('your BOBCARD ending 9012 at', '9012', AccountKind.card),
      ('debited from HDFC Bank XX1234 on', '1234', AccountKind.account),
    ];
    for (final (text, last4, kind) in rows) {
      test(text, () {
        expect(AccountExtractor.extract(text), AccountRef(last4, kind));
      });
    }
  });

  test('a masked mobile number is not an account', () {
    expect(
      AccountExtractor.extract('by A/c linked to mobile 9XXXXXX123'),
      isNull,
    );
  });

  group('reference numbers', () {
    const rows = [
      ('UPI/P2M/526812345678/SWIGGY', '526812345678'),
      ('Ref 526812345678.', '526812345678'),
      ('(UPI 524412345678)', '524412345678'),
      ('UPI:526612345678-ICICI Bank', '526612345678'),
      ('IMPS Ref No. 626312345678', '626312345678'),
      (
        'Your UPI transaction reference number is 526812345678.',
        '526812345678',
      ),
      ('UTR: CITIN52026090112345.', 'CITIN52026090112345'),
      ('Transaction number 626112345678.', '626112345678'),
      ('RRN 525912345678', '525912345678'),
      // TC-06-11: "UPI transaction ID" retry finds the inner label.
      ('UPI transaction ID 526812345678', '526812345678'),
    ];
    for (final (text, ref) in rows) {
      test(text, () => expect(ReferenceExtractor.extract(text), ref));
    }
  });

  test('words after a reference label are not references', () {
    expect(
      ReferenceExtractor.extract('UPI transaction refundable within 5 days'),
      isNull,
    );
  });

  test('reference normalisation needs six letters or digits', () {
    expect(ReferenceExtractor.normalize('ab-12 3'), isNull);
    expect(ReferenceExtractor.normalize('ab-12 345'), 'AB12345');
    expect(ReferenceExtractor.normalize(null), isNull);
  });

  group('date and time formats', () {
    const rows = [
      ('on 25/09/26', '2026-09-25', null),
      ('on 25-09-2026 at 10:15:32', '2026-09-25', '10:15:32'),
      ('on 25-Sep-26', '2026-09-25', null),
      ('on date 25Sep26 trf', '2026-09-25', null),
      ('on 01-SEP-26 for', '2026-09-01', null),
      ('on 2026-09-24:18:22:10.', '2026-09-24', '18:22:10'),
      ('(2026:09:25 10:15:32)', '2026-09-25', '10:15:32'),
      ('on Sep 22, 2026 at 18:10:05', '2026-09-22', '18:10:05'),
      ('on 22/09/2026 at 06:40 PM', '2026-09-22', '18:40:00'),
      ('on 12SEP26 14:35', '2026-09-12', '14:35:00'),
    ];
    for (final (text, date, time) in rows) {
      test(text, () {
        final parts = DateTimeExtractor.extract(text);
        expect(parts.date.toString(), date);
        expect(parts.time?.toString(), time);
      });
    }
  });

  test('an impossible date is ignored', () {
    expect(DateTimeExtractor.extract('on 31/02/26').date, isNull);
    expect(DateTimeExtractor.extract('on 01/01/1999').date, isNull);
  });

  test('type follows the first money verb', () {
    expect(
      TypeClassifier.classify('INR 240 debited; SWIGGY credited'),
      TransactionType.debit,
    );
    expect(
      TypeClassifier.classify(
        'INR 500 credited to A/c from VPA x@y. Debit card',
      ),
      TransactionType.credit,
    );
    expect(
      TypeClassifier.classify(
        'Payment of INR 5,000.00 received towards your Credit Card XX1',
      ),
      TransactionType.transfer,
    );
    expect(TypeClassifier.classify('Your balance is INR 500'), isNull);
  });

  test('channel detection', () {
    expect(ChannelDetector.detect('withdrawn at ATM'), Channel.atm);
    expect(ChannelDetector.detect('to VPA a@okaxis'), Channel.upi);
    expect(ChannelDetector.detect('Info: ACH D- ZERODHA'), Channel.autoDebit);
    expect(ChannelDetector.detect('by NEFT from ACME'), Channel.neft);
    expect(ChannelDetector.detect('spent on Card XX1 at AMAZON'), Channel.card);
    expect(ChannelDetector.detect('by IMPS to X'), Channel.imps);
    expect(ChannelDetector.detect('credited via RTGS'), Channel.rtgs);
    expect(ChannelDetector.detect('hello'), Channel.other);
  });

  test('merchant patterns', () {
    const debit = TransactionType.debit;
    expect(
      MerchantExtractor.extract('UPI/P2M/526812345678/SWIGGY. Not you?', debit),
      const RawMerchant('SWIGGY', null),
    );
    expect(
      MerchantExtractor.extract(
        'debited to VPA swiggy@icici SWIGGY on 25-09-26',
        debit,
      ),
      const RawMerchant('SWIGGY', 'swiggy@icici'),
    );
    expect(
      MerchantExtractor.extract(
        'spent on Card x1 at AMAZON PAY INDIA on 2026-09-24',
        debit,
      ),
      const RawMerchant('AMAZON PAY INDIA', null),
    );
    expect(
      MerchantExtractor.extract(
        'credited with INR 5 by NEFT from JOHN DOE. UPI',
        TransactionType.credit,
      ),
      const RawMerchant('JOHN DOE', null),
    );
    expect(
      MerchantExtractor.extract(
        'Sent INR 5 to rahul.sharma@oksbi on 08-09-26',
        debit,
      ),
      const RawMerchant(null, 'rahul.sharma@oksbi'),
    );
  });

  test('ui phrases are not merchants', () {
    for (final p in [
      'View Details',
      'Click here',
      'Know more',
      'Open app',
      'Tap to view',
    ]) {
      expect(GenericPhrases.isGeneric(p), isTrue, reason: p);
      expect(
        MerchantExtractor.extract(
          'Rs 144 debited from A/c XX1234 at $p. Ref 1',
          TransactionType.debit,
        ).name,
        isNull,
        reason: p,
      );
    }
    expect(GenericPhrases.isGeneric('Swiggy'), isFalse);
  });
}

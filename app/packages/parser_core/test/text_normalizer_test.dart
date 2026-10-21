// Port of TextNormalizerTest (FR-06-01, TC-06-01, TC-06-02).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

void main() {
  group('every rupee spelling becomes INR', () {
    const rows = [
      ('Rs.250.00 spent', 'INR 250.00 spent'),
      ('Rs 1,23,456.00 spent', 'INR 1,23,456.00 spent'),
      ('rs.99 paid', 'INR 99 paid'),
      ('₹500 sent', 'INR 500 sent'),
      ('₹ 500 sent', 'INR 500 sent'),
      ('INR5,000.00 credited', 'INR 5,000.00 credited'),
      ('INR. 10 debited', 'INR 10 debited'),
      ('AvlBal:Rs12090.50', 'AvlBal:INR 12090.50'),
      ('Mrs 500 is not a currency', 'Mrs 500 is not a currency'),
      ('Rs250 paid', 'INR 250 paid'),
      ('INR.250 paid', 'INR 250 paid'),
    ];
    for (final (raw, expected) in rows) {
      test(raw, () => expect(TextNormalizer.normalize(raw), expected));
    }
  });

  test('zero-width characters and odd spaces are removed', () {
    expect(
      TextNormalizer.normalize(
        'Rs.2​50.00 debited‍ from A/c XX1234﻿',
      ),
      'INR 250.00 debited from A/c XX1234',
    );
    expect(TextNormalizer.normalize('a b c d'), 'a b c d');
  });

  test(
      'line breaks become sentence ends unless punctuation already ends the '
      'line', () {
    expect(
      TextNormalizer.normalize(
        'Credit Alert!\nRs.5.00 credited\r\nA/c XX1234\n\n  On 25/09/26',
      ),
      'Credit Alert! INR 5.00 credited. A/c XX1234. On 25/09/26',
    );
    expect(
      TextNormalizer.normalize('Rs.1,500.00 debited\nA/c XX1'),
      'INR 1,500.00 debited. A/c XX1',
    );
  });

  test('whitespace is collapsed and trimmed', () {
    expect(TextNormalizer.normalize('   a    b \t c  '), 'a b c');
    expect(TextNormalizer.normalize(''), '');
  });

  test('email footer and disclaimers are cut', () {
    final body = TextNormalizer.normalize(
      'Dear Customer, INR 450.00 has been debited from account **1234 to VPA '
      'x@ybl on 25-09-26. If you did not authorize this transaction, call '
      'us. Never share your OTP. Get pre-approved loans! Apply now.',
    );
    final trimmed = TextNormalizer.trimEmail(body);
    expect(trimmed.endsWith('on 25-09-26.'), isTrue, reason: trimmed);
  });

  test('a footer marker at the very start does not erase the body', () {
    const body =
        'Regards, INR 10.00 has been debited from account XX1234 on 25-09-26 '
        'towards SWIGGY';
    expect(TextNormalizer.trimEmail(body), body);
  });

  test('trimEmail caps the body at 3000 characters', () {
    final long = 'x' * 4000;
    expect(TextNormalizer.trimEmail(long).length, 3000);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';

void main() {
  group('formatMoney (en-IN, paise)', () {
    test('groups lakh and crore', () {
      expect(formatMoney(const Money(12345678)), '₹1,23,456.78');
      expect(formatMoney(const Money(1000000000)), '₹1,00,00,000.00');
      expect(formatMoney(const Money(99999)), '₹999.99');
      expect(formatMoney(const Money(100000)), '₹1,000.00');
    });
    test('handles zero, sub-rupee and negatives', () {
      expect(formatMoney(Money.zero), '₹0.00');
      expect(formatMoney(const Money(5)), '₹0.05');
      expect(formatMoney(const Money(-12345)), '-₹123.45');
    });
    test('can drop paise and mask', () {
      expect(formatMoney(const Money(12345600), showPaise: false), '₹1,23,456');
      expect(formatMoney(const Money(12345600), masked: true), '₹••••');
    });
    test('uses the currency symbol', () {
      expect(formatMoney(const Money(250, currency: 'USD')), r'$2.50');
    });
  });

  group('parseMoney', () {
    test('parses grouped and symbol input without doubles', () {
      expect(parseMoney('1,23,456.78'), const Money(12345678));
      expect(parseMoney('₹ 500'), const Money(50000));
      expect(parseMoney('0.5'), const Money(50));
      expect(parseMoney('-12.05'), const Money(-1205));
    });
    test('rejects bad input', () {
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney('1.234'), isNull);
    });
    test('round trips through formatMoney', () {
      const m = Money(987654321);
      expect(parseMoney(formatMoney(m)), m);
    });
  });

  group('Money', () {
    test('adds and subtracts', () {
      expect(const Money(100) + const Money(50), const Money(150));
      expect(const Money(100) - const Money(150), const Money(-50));
      expect(-const Money(100), const Money(-100));
    });
    test('refuses mixed currencies', () {
      expect(
        () => const Money(1) + const Money(1, currency: 'USD'),
        throwsArgumentError,
      );
    });
  });
}

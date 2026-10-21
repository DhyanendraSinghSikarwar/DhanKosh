// Payment-app notification layouts, bank UPI SMS and payment-app receipt
// emails. Port of NotificationLayoutsTest (FR-06-16, TC-06-22).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/notification_cases.dart';

void main() {
  const free = FreeTextParser();

  test('at least forty layouts are covered', () {
    expect(notificationCases.length, greaterThanOrEqualTo(40));
  });

  test('every layout parses, or is skipped, as expected', () {
    for (final c in notificationCases) {
      final label = '${c.app}: ${c.title} / ${c.body}';
      final tx = free.fromNotification(c.app, c.title, c.body, 1760000000000);
      if (c.type == null) {
        expect(tx, isNull, reason: label);
        continue;
      }
      expect(tx, isNotNull, reason: label);
      expect(tx!.type, c.type, reason: label);
      expect(tx.amountMinor, c.minor, reason: label);
      if (c.merchant != null) expect(tx.merchant, c.merchant, reason: label);
      if (c.upi != null) expect(tx.upiId, c.upi, reason: label);
    }
  });

  test('fields combine in any order and duplicates are harmless', () {
    final a = free.readNotification(
      'PhonePe',
      ['Paid ₹250', 'to Ravi Kumar', 'to Ravi Kumar • UPI', 'Paid ₹250', 'UPI'],
      1,
    );
    expect(a.tx!.amountMinor, 25000);
    expect(a.tx!.merchant, 'Ravi Kumar');
    expect(a.tx!.channel, Channel.upi);
    final b = free.readNotification(
      'PhonePe',
      [
        'Payment failed',
        '₹250 paid to Ravi',
      ],
      1,
    );
    expect(b.tx, isNull);
    expect(b.skipReason, 'failed or pending payment');
  });

  test('a mandate payment is an auto debit', () {
    final tx = free.fromNotification(
      'PhonePe',
      'AutoPay',
      '₹199 paid to Netflix via AutoPay',
      1,
    );
    expect(tx!.channel, Channel.autoDebit);
  });

  test('bank UPI sms and payment app emails parse', () {
    final registry = ParserRegistry.standard();
    for (final c in receiptCases) {
      final label = '${c.sender}: ${c.body}';
      final tx = registry.parse(c.body, c.sender, 1760000000000, c.source);
      if (c.type == null) {
        expect(tx, isNull, reason: label);
        continue;
      }
      expect(tx, isNotNull, reason: label);
      expect(tx!.type, c.type, reason: label);
      expect(tx.amountMinor, c.minor, reason: label);
      if (c.merchant != null) expect(tx.merchant, c.merchant, reason: label);
      if (c.last4 != null) expect(tx.accountLast4, c.last4, reason: label);
      if (c.ref != null) expect(tx.referenceNumber, c.ref, reason: label);
    }
  });

  test('payment app email senders are in the default whitelist', () {
    final senders = ParserRegistry.standard().defaultEmailSenders;
    expect(senders, contains('phonepe.com'));
  });
}

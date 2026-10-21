// Credit-card spend, refund and international alerts from every issuer, in each
// layout generation, by SMS and by email. The card's last four digits, the
// merchant and the available limit must come from the shared extractors, never
// from the helpline number in the "Not you? ... BLOCK" boilerplate. Port of
// CardAlertsTest (FR-06-07, FR-06-12).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/card_alert_cases.dart';

final _registry = ParserRegistry.standard();
final int _received = epochOf(
  const CivilDate(2026, 10, 8),
  const CivilTime(12, 0),
  const Duration(hours: 5, minutes: 30),
);
final RegExp _junk = RegExp(
  r'not\s+you|block|dispute|report|call\s|\d{6,}|sms\s',
  caseSensitive: false,
);

int _minor(String major) => Money.parse(major)!.minor;

/// The first thing that is wrong with how [c] parsed, or null.
String? check(CardAlertCase c) {
  final tx = _registry.parse(c.body, c.sender, _received, c.source);
  if (tx == null) return 'not parsed: $c';
  if (tx.type != c.type) return 'type ${tx.type} != ${c.type}: $c';
  if (tx.amountMinor != _minor(c.amount)) {
    return 'amount ${tx.amountMinor} != ${_minor(c.amount)}: $c';
  }
  if (tx.currency != c.currency) {
    return 'currency ${tx.currency} != ${c.currency}: $c';
  }
  if (tx.accountKind != AccountKind.card) return 'kind ${tx.accountKind}: $c';
  if (tx.accountLast4 != c.last4) {
    return 'last4 ${tx.accountLast4} != ${c.last4}: $c';
  }
  final merchant = tx.merchant;
  if (c.merchant != null &&
      !(merchant?.toLowerCase().contains(c.merchant!.toLowerCase()) ?? false)) {
    return "merchant '$merchant' lacks '${c.merchant}': $c";
  }
  if (merchant != null && _junk.hasMatch(merchant)) {
    return "merchant '$merchant' is boilerplate: $c";
  }
  if (c.limit != null && tx.availableLimitMinor != _minor(c.limit!)) {
    return 'limit ${tx.availableLimitMinor} != ${_minor(c.limit!)}: $c';
  }
  if (tx.balanceMinor != null) {
    return 'card alert read a bank balance ${tx.balanceMinor}: $c';
  }
  return null;
}

void main() {
  group('card alert parses', () {
    for (final c in cardAlertCases) {
      test(c.toString(), () {
        final error = check(c);
        expect(error, isNull, reason: error);
      });
    }
  });

  test('card issuer senders pass the pre-filter', () {
    for (final s in cardIssuerSenders) {
      expect(_registry.accepts(s), isTrue, reason: 'pre-filter drops $s');
    }
    for (final s in ['VM-AMAZON', 'AD-SWIGGY', '+919876543210', 'JD-FLPKRT']) {
      expect(_registry.accepts(s), isFalse, reason: s);
    }
  });

  test('corpus covers every issuer', () {
    final perIssuer = <String, int>{};
    for (final c in cardAlertCases) {
      perIssuer[c.issuer] = (perIssuer[c.issuer] ?? 0) + 1;
    }
    perIssuer.forEach((issuer, n) {
      expect(
        n,
        greaterThanOrEqualTo(2),
        reason: '$issuer has only $n fixtures',
      );
    });
    expect(perIssuer['Axis'], isNotNull);
  });
}

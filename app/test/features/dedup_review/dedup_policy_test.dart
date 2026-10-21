import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/dedup_review/domain/dedup_policy.dart';
import 'package:hisaab/features/dedup_review/domain/merge_rules.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';

DedupCandidate cand(
  ParsedTransaction p, {
  int id = 1,
  Set<Source>? sources,
}) =>
    DedupCandidate(
      id: id,
      amountMinor: p.amountMinor,
      currency: p.currency,
      type: p.type,
      timestamp: p.transactionTime,
      hasExplicitTime: p.hasExplicitTime,
      transactionHash: p.transactionHash,
      category: p.category,
      confidence: p.confidence,
      sources: sources ?? {p.source},
      referenceNumber: p.referenceNumber,
      accountLast4: p.accountLast4,
      merchant: p.merchant,
      upiId: p.upiId,
      balanceMinor: p.balanceMinor,
      availableLimitMinor: p.availableLimitMinor,
    );

void main() {
  const policy = DedupPolicy();

  test('no candidates is New', () {
    expect(policy.decide(parsed(), const []), isA<DedupNew>());
  });

  // FR-07-02
  test('same reference, amount and direction is a REFERENCE duplicate', () {
    final stored = parsed(time: t0 - 5 * hour, last4: null);
    final d = policy.decide(
      parsed(source: Source.email),
      [cand(stored)],
    );
    expect(d, isA<DedupDuplicate>());
    expect((d as DedupDuplicate).reason, DuplicateReason.reference);
  });

  test('same reference but different amount is not a duplicate', () {
    final stored = parsed(amountMinor: 30000);
    expect(
      policy.decide(parsed(source: Source.email), [cand(stored)]),
      isA<DedupNew>(),
    );
  });

  // FR-07-03
  test('same hash, other source, within 30 min merges by HASH', () {
    final stored = parsed(ref: null);
    final incoming = parsed(ref: null, source: Source.email, time: t0 + minute);
    // hashes agree only when the day agrees; same IST day here.
    final d = policy.decide(incoming, [cand(stored)]);
    expect((d as DedupDuplicate).reason, DuplicateReason.hash);
  });

  test('same source twice without a reference is flagged', () {
    final stored = parsed(ref: null);
    final d = policy.decide(parsed(ref: null), [cand(stored)]);
    expect(d, isA<DedupPossible>());
    expect(
      (d as DedupPossible).reasonText,
      'Same amount, account and day, no reference number',
    );
  });

  // FR-07-03/04: time-window rule (hours apart, missing reference).
  test('hash match hours apart with a missing reference falls to review', () {
    final stored = parsed(ref: null);
    final incoming =
        parsed(ref: null, source: Source.email, time: t0 + 2 * hour);
    final d = policy.decide(incoming, [cand(stored)]);
    expect(d, isA<DedupPossible>());
    expect(
      (d as DedupPossible).reasonText,
      'Same amount and account on the same day, from SMS and email',
    );
  });

  test('beyond 12 h an uncertain pair is New', () {
    final stored = parsed(ref: null, last4: null, merchant: null);
    final incoming = parsed(
      ref: null,
      source: Source.email,
      time: t0 + 13 * hour,
    );
    expect(policy.decide(incoming, [cand(stored)]), isA<DedupNew>());
  });

  // FR-07-04
  test('close in time, cross source, same account merges FUZZY', () {
    final stored = parsed(ref: null, merchant: null);
    final incoming = parsed(
      ref: 'ABC123456',
      source: Source.email,
      time: t0 + 10 * minute,
      merchant: null,
    );
    final d = policy.decide(incoming, [cand(stored)]);
    expect((d as DedupDuplicate).reason, DuplicateReason.fuzzy);
  });

  test('differing references or accounts never match', () {
    final stored = parsed(ref: 'AAAAAA111');
    expect(
      policy.decide(
        parsed(ref: 'BBBBBB222', source: Source.email, time: t0 + minute),
        [cand(stored)],
      ),
      isA<DedupNew>(),
    );
    expect(
      policy.decide(
        parsed(
          ref: null,
          last4: '9999',
          source: Source.email,
          time: t0 + minute,
        ),
        [cand(parsed(ref: null, merchant: 'Other'))],
      ),
      isA<DedupNew>(),
    );
  });

  // FR-07-05
  test('statement row merges within 36 h without review', () {
    final stored = parsed(ref: null);
    final incoming = parsed(
      ref: null,
      source: Source.statement,
      time: t0 + 20 * hour,
    );
    final d = policy.decide(incoming, [cand(stored)]);
    expect(d, isA<DedupDuplicate>());
  });

  // FR-07-06
  test('payment-app whole-rupee amount merges with the bank paise row', () {
    final bank = parsed(amountMinor: 24975, ref: null);
    final app = parsed(
      amountMinor: 24900,
      source: Source.app,
      last4: null,
      ref: null,
      time: t0 + 2 * hour,
    );
    final d = policy.decide(app, [cand(bank)]);
    expect(d, isA<DedupDuplicate>());
  });

  test('rounded match fails outside the +1..+99 paise range', () {
    final bank = parsed(amountMinor: 25100, ref: null);
    final app = parsed(
      amountMinor: 24900,
      source: Source.app,
      last4: null,
      ref: null,
    );
    expect(policy.decide(app, [cand(bank)]), isA<DedupNew>());
  });

  test('merchantsAgree rules', () {
    expect(DedupPolicy.merchantsAgree(null, 'Swiggy'), isTrue);
    expect(DedupPolicy.merchantsAgree('Swiggy', 'SWIGGY LTD'), isTrue);
    expect(DedupPolicy.merchantsAgree('Big Basket', 'Basket Co'), isTrue);
    expect(DedupPolicy.merchantsAgree('Swiggy', 'Zomato'), isFalse);
  });

  // FR-07-09
  test('merge fills gaps and keeps stored values', () {
    final stored = parsed(
      amountMinor: 24900,
      ref: null,
      merchant: 'x@ybl',
      last4: '123',
      category: Category.other,
    );
    final incoming = parsed(
      amountMinor: 24950,
      ref: 'REF123456',
      last4: '0123',
      balance: 100000,
      time: t0 + 10 * minute,
    );
    final m = mergeInto(cand(stored), incoming);
    expect(m.amountMinor, 24950);
    expect(m.merchant, 'Swiggy');
    expect(m.referenceNumber, 'REF123456');
    expect(m.accountLast4, '0123');
    expect(m.category, Category.food);
    expect(m.balanceMinor, 100000);
    // Balance rule: stored time is not after the incoming time.
    expect(m.timestamp, t0);
  });
}

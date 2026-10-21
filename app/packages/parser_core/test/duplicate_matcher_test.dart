// The dedup scenarios from the spec, run through the real parser and an
// in-memory store. Port of DuplicateMatcherTest (FR-07-02..FR-07-06,
// TC-07-02..TC-07-06).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

const _minute = 60000;
final int _t0 = receivedAt;

/// Mimics the Drift layer: insert on New, attach a source on Duplicate.
class _Store extends DedupLookup {
  final List<StoredTransaction> rows = [];
  final Map<String, int> hashes = {};
  int nextId = 1;

  void apply(ParsedTransaction tx, DedupDecision decision) {
    if (decision is Duplicate) {
      final i = rows.indexWhere((r) => r.id == decision.existingId);
      rows[i] = rows[i].copyWith(
        sources: {...rows[i].sources, sourceKey(tx.source)},
        referenceNumber: rows[i].referenceNumber ?? tx.referenceNumber,
        merchant: rows[i].merchant ?? tx.merchant,
      );
      hashes[tx.transactionHash] = decision.existingId;
    } else {
      final id = nextId++;
      rows.add(
        StoredTransaction(
          id: id,
          amountMinor: tx.amountMinor,
          type: tx.type,
          accountLast4: tx.accountLast4,
          merchant: tx.merchant,
          referenceNumber: tx.referenceNumber,
          transactionTime: tx.transactionTime,
          sources: {sourceKey(tx.source)},
        ),
      );
      hashes[tx.transactionHash] = id;
    }
  }

  @override
  Future<List<StoredTransaction>> byReference(String referenceNumber) async => [
        for (final r in rows)
          if (r.referenceNumber == referenceNumber) r,
      ];

  @override
  Future<StoredTransaction?> byHash(String transactionHash) async {
    final id = hashes[transactionHash];
    if (id == null) return null;
    return rows.firstWhere((r) => r.id == id);
  }

  @override
  Future<List<StoredTransaction>> potentialDuplicates(
    int amountMinor,
    int from,
    int to,
  ) async =>
      [
        for (final r in rows)
          if (r.amountMinor == amountMinor &&
              r.transactionTime >= from &&
              r.transactionTime <= to)
            r,
      ];
}

final ParserRegistry _registry = ParserRegistry.standard();

ParsedTransaction _sms(String body, {int? at, String sender = 'VM-HDFCBK'}) =>
    _registry.parse(body, sender, at ?? _t0, Source.sms)!;

ParsedTransaction _mail(
  String body, {
  int? at,
  String sender = 'alerts@hdfcbank.net',
}) =>
    _registry.parse(body, sender, at ?? _t0, Source.email)!;

Future<List<DedupDecision>> _ingest(
  _Store store,
  List<ParsedTransaction> txs,
) async {
  final out = <DedupDecision>[];
  for (final tx in txs) {
    final d = await DuplicateMatcher.decide(tx, store);
    store.apply(tx, d);
    out.add(d);
  }
  return out;
}

// One UPI payment, reported by SMS (with reference) and by email (without it).
const _smsWithRef =
    'Rs.450.00 debited from HDFC Bank A/c XX1234 on 25-09-26 to VPA '
    'swiggy@icici. UPI Ref 526812345678. Avl bal:INR 9,550.00';
const _emailNoRef =
    'Dear Customer,\nRs.450.00 has been debited from account **1234 to VPA '
    'swiggy@icici SWIGGY on 25-09-26.';
const _emailWithRef =
    'Dear Customer,\nRs.450.00 has been debited from account **1234 to VPA '
    'swiggy@icici SWIGGY on 25-09-26.\nYour UPI transaction reference number '
    'is 526812345678.';

// A payment-app notification with a rounded amount and no merchant, then the
// card SMS with paise.
const _cardSms =
    'Rs.144.93 spent on your SBI Credit Card ending 5678 at JIOHOTSTAR on '
    '07/10/26. Trxn. not done by you? Report at sbicard.com';

ParsedTransaction _notification(
  String amount, {
  String title = 'Payment successful',
  String? body,
  int? at,
}) =>
    const FreeTextParser().fromNotification(
      'Google Pay',
      title,
      body ?? '$amount paid. View Details',
      at ?? _t0 + 60 * _minute,
    )!;

StoredTransaction _typed(
  Set<String> sources,
  String? last4,
  ParsedTransaction tx,
) =>
    StoredTransaction(
      id: 1,
      amountMinor: tx.amountMinor,
      type: tx.type,
      accountLast4: last4,
      merchant: 'Ravi Kumar',
      referenceNumber: null,
      transactionTime: tx.transactionTime - 5 * _minute,
      sources: sources,
    );

void main() {
  test('sms then email for the same transaction is one record', () async {
    final store = _Store();
    final d = await _ingest(store, [
      _sms(_smsWithRef),
      _mail(_emailWithRef, at: _t0 + 2 * _minute),
    ]);
    expect(d[0], const NewTransaction());
    expect(d[1], isA<Duplicate>());
    expect(store.rows.length, 1);
    expect(store.rows.single.sources, {'SMS', 'EMAIL'});
  });

  test('email then sms for the same transaction is one record', () async {
    final store = _Store();
    final d = await _ingest(store, [
      _mail(_emailWithRef),
      _sms(_smsWithRef, at: _t0 + _minute),
    ]);
    expect((d[1] as Duplicate).reason, MatchReason.reference);
    expect(store.rows.length, 1);
  });

  test('email delayed by 25 minutes still merges', () async {
    final store = _Store();
    final d = await _ingest(store, [
      _sms(_smsWithRef),
      _mail(_emailNoRef, at: _t0 + 25 * _minute),
    ]);
    expect(d[1], const Duplicate(1, MatchReason.fuzzy));
    expect(store.rows.length, 1);
  });

  test(
      'missing reference on both sides merges by account, amount and '
      'time', () async {
    final store = _Store();
    const cardSms =
        'Rs.1500.00 spent on HDFC Bank Card x5678 at AMAZON PAY INDIA on '
        '2026-09-24:18:22:10.';
    const cardMail =
        'Dear Card Member,\nThank you for using your HDFC Bank Credit Card '
        'ending 5678 for Rs 1,500.00 at AMAZON PAY INDIA on 24-09-2026 '
        '18:22:10.';
    final d = await _ingest(store, [
      _sms(cardSms),
      _mail(cardMail, at: _t0 + 3 * _minute),
    ]);
    expect(d[1], isA<Duplicate>());
    expect(store.rows.length, 1);
  });

  test(
      'email hours late on the same account goes to review instead of '
      'duplicating silently', () async {
    final store = _Store();
    final d = await _ingest(store, [
      _sms(_smsWithRef),
      _mail(_emailNoRef, at: _t0 + 3 * 60 * _minute),
    ]);
    expect(d[1], isA<PossibleDuplicate>());
  });

  test(
      'two real purchases of the same amount with different references stay '
      'separate', () async {
    final store = _Store();
    final a = _sms(
      'Rs.20.00 debited from HDFC Bank A/c XX1234 on 25-09-26 to VPA '
      'chai@ybl. UPI Ref 526800000001',
    );
    final b = _sms(
      'Rs.20.00 debited from HDFC Bank A/c XX1234 on 25-09-26 to VPA '
      'chai@ybl. UPI Ref 526800000002',
      at: _t0 + 5 * _minute,
    );
    expect(await _ingest(store, [a, b]), const [
      NewTransaction(),
      NewTransaction(),
    ]);
  });

  test('same amount on different accounts stays separate', () async {
    final store = _Store();
    final a = _sms(
      'Rs.500.00 spent on HDFC Bank Card x5678 at UBER on 2026-09-25:10:00:00.',
    );
    final b = _mail(
      'Dear Customer,\nRs.500.00 has been debited from account **1234 to VPA '
      'x@ybl RAHUL on 25-09-26.',
      at: _t0 + _minute,
    );
    final d = await _ingest(store, [a, b]);
    expect(d[1], const NewTransaction());
  });

  test(
      'two sms without references for the same amount and card go to '
      'review', () async {
    final store = _Store();
    final a = _sms(
      'Rs.120.00 spent on HDFC Bank Card x5678 at STARBUCKS on 2026-09-25:10:00:00.',
    );
    final b = _sms(
      'Rs.120.00 spent on HDFC Bank Card x5678 at STARBUCKS on '
      '2026-09-25:10:04:00.',
      at: _t0 + 4 * _minute,
    );
    final d = await _ingest(store, [a, b]);
    expect(d[1], isA<PossibleDuplicate>());
    expect(store.rows.length, 2);
  });

  test('debit and credit of the same amount are never duplicates', () async {
    final store = _Store();
    final a = _sms(
      'Rs.500.00 debited from HDFC Bank A/c XX1234 on 25-09-26 to VPA x@ybl. '
      'UPI Ref 526800000011',
    );
    final b = _sms(
      'Rs.500.00 credited to HDFC Bank A/c XX1234 on 25-09-26 from VPA x@ybl. '
      'UPI Ref 526800000012',
      at: _t0 + _minute,
    );
    expect((await _ingest(store, [a, b]))[1], const NewTransaction());
  });

  test('combined sms and email corpus produces zero duplicates', () async {
    // Every transaction arrives twice, once per source, in shuffled order with
    // a small delay.
    final store = _Store();
    final pairs = <ParsedTransaction>[];
    for (var i = 0; i < 40; i++) {
      final amount = 100 + i * 7;
      final ref = '5268${i.toString().padLeft(8, '0')}';
      final at = _t0 - i * 90 * _minute;
      final s = _sms(
        'Rs.$amount.00 debited from HDFC Bank A/c XX1234 on 25-09-26 to VPA '
        'shop$i@ybl. UPI Ref $ref',
        at: at,
      );
      final m = _mail(
        'Dear Customer,\nRs.$amount.00 has been debited from account **1234 '
        'to VPA shop$i@ybl SHOP on 25-09-26.'
        '${i.isEven ? '\nYour UPI transaction reference number is $ref.' : ''}',
        at: at + (i % 5) * 5 * _minute,
      );
      pairs.addAll(i % 3 == 0 ? [m, s] : [s, m]);
    }
    await _ingest(store, pairs);
    expect(store.rows.length, 40);
    expect(
      store.rows
          .where(
            (r) =>
                r.sources.length == 2 &&
                r.sources.containsAll({'SMS', 'EMAIL'}),
          )
          .length,
      40,
    );
  });

  test(
      'rounded app notification matches the sms with paise even without a '
      'merchant', () async {
    final app = _notification('₹144');
    expect(app.amountMinor, 14400);
    expect(app.merchant, isNull);
    final sms = _registry.parse(
      _cardSms,
      'VM-SBICRD',
      _t0 + 3 * 60 * _minute,
      Source.sms,
    )!;
    expect(sms.amountMinor, 14493);
    // notification first, then the SMS
    final s1 = _Store();
    final d1 = await _ingest(s1, [app, sms]);
    expect(d1[1], isA<Duplicate>());
    expect(s1.rows.length, 1);
    // SMS first, then the notification
    final s2 = _Store();
    final d2 = await _ingest(s2, [sms, app]);
    expect(d2[1], isA<Duplicate>());
    expect(s2.rows.length, 1);
  });

  test('rounded app match needs the same merchant, direction and day',
      () async {
    final sms = _registry.parse(_cardSms, 'VM-SBICRD', _t0, Source.sms)!;
    final other = _notification(
      '₹144',
      title: '₹144 paid to Swiggy',
      body: 'Payment successful',
    );
    expect((await _ingest(_Store(), [sms, other]))[1], const NewTransaction());
    final nextWeek = _notification('₹144', at: _t0 + 7 * 24 * 60 * _minute);
    expect(
      (await _ingest(_Store(), [sms, nextWeek]))[1],
      const NewTransaction(),
    );
    final offBy = _notification('₹145');
    expect((await _ingest(_Store(), [sms, offBy]))[1], const NewTransaction());
  });

  test('phonepe notification and bank sms merge in either order', () async {
    final app = _notification(
      '₹450',
      title: 'Paid ₹450',
      body: 'to Swiggy',
      at: _t0 + 2 * _minute,
    );
    final bank = _sms(_smsWithRef);
    final s1 = _Store();
    expect((await _ingest(s1, [app, bank]))[1], isA<Duplicate>());
    expect(s1.rows.length, 1);
    final s2 = _Store();
    expect((await _ingest(s2, [bank, app]))[1], isA<Duplicate>());
    expect(s2.rows.length, 1);
    expect(s2.rows.single.sources, {'SMS', 'APP'});
  });

  test(
      'same amount to a different payee minutes apart is another '
      'payment', () async {
    final app = _notification(
      '₹450',
      title: 'Paid ₹450',
      body: 'to Ravi Kumar',
      at: _t0 + 5 * _minute,
    );
    expect(
      (await _ingest(_Store(), [_sms(_smsWithRef), app]))[1],
      const NewTransaction(),
    );
  });

  test(
      'same card same amount hours apart without a reference is not a '
      'silent duplicate', () async {
    final morning = _sms(
      'Rs.1500.00 spent on HDFC Bank Card x5678 at AMAZON PAY INDIA on '
      '2026-09-24:09:22:10.',
    );
    final evening = _mail(
      'Dear Card Member,\nThank you for using your HDFC Bank Credit Card '
      'ending 5678 for Rs 1,500.00 at AMAZON PAY INDIA on 24-09-2026 '
      '20:40:00.',
    );
    final d = (await _ingest(_Store(), [morning, evening]))[1];
    expect(d is Duplicate, isFalse);
  });

  test('two bank sms with different paise are not merged', () async {
    final a = _registry.parse(_cardSms, 'VM-SBICRD', _t0, Source.sms)!;
    final b = _registry.parse(
      _cardSms.replaceAll('144.93', '144.00'),
      'VM-SBICRD',
      _t0 + 5 * _minute,
      Source.sms,
    )!;
    expect((await _ingest(_Store(), [a, b]))[1], const NewTransaction());
  });

  test(
      'a typed payment on the account merges with the bank sms that comes '
      'later', () async {
    final bank = _sms(_smsWithRef);
    final store = _Store()..rows.add(_typed({'MANUAL'}, '1234', bank));
    final d = await DuplicateMatcher.decide(bank, store);
    expect((d as Duplicate).existingId, 1);
  });

  test(
      'a notification assigned to the account merges with its bank sms '
      'once', () async {
    final bank = _sms(_smsWithRef);
    final store = _Store()..rows.add(_typed({'APP'}, '1234', bank));
    expect(await DuplicateMatcher.decide(bank, store), isA<Duplicate>());
    // Assigned to another account, the same amount is a different payment.
    final other = _Store()..rows.add(_typed({'APP'}, '9999', bank));
    expect(await DuplicateMatcher.decide(bank, other), const NewTransaction());
  });

  test(
      'the same source without a reference is a possible duplicate '
      '(FR-07-03)', () async {
    final a = _sms(
      'Rs.120.00 spent on HDFC Bank Card x5678 at STARBUCKS on 2026-09-25:10:00:00.',
    );
    final store = _Store();
    await _ingest(store, [a]);
    final again = await DuplicateMatcher.decide(a, store);
    expect(again, isA<PossibleDuplicate>());
    expect(
      (again as PossibleDuplicate).reason,
      'Same amount, account and day, no reference number',
    );
  });

  test('merchantsAgree and last4Match helpers', () {
    expect(DuplicateMatcher.merchantsAgree(null, 'Swiggy'), isTrue);
    expect(DuplicateMatcher.merchantsAgree('View Details', 'Swiggy'), isTrue);
    expect(
      DuplicateMatcher.merchantsAgree('Swiggy', 'Swiggy Instamart'),
      isTrue,
    );
    expect(DuplicateMatcher.merchantsAgree('Ravi Kumar', 'R Kumar'), isTrue);
    expect(DuplicateMatcher.merchantsAgree('Swiggy', 'Zomato'), isFalse);
    expect(DuplicateMatcher.last4Match('123', '0123'), isTrue);
    expect(DuplicateMatcher.last4Match('1234', '9999'), isFalse);
  });
}

// More dedup checks (FR-07-19, FR-07-20, FR-07-21, FR-07-22): hardened
// references, two apps for one payment, stated balances, printed times and
// late mail. Every message is synthetic; times are minutes from a fixed day.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

const _min = 60000;
const int _hour = 60 * _min;
final int _t0 = DateTime.utc(2026, 11, 4, 4, 30).millisecondsSinceEpoch;

ParsedTransaction _tx({
  required int amount,
  Source source = Source.sms,
  TransactionType type = TransactionType.debit,
  String? last4 = '1234',
  String? ref,
  String? merchant,
  int? balance,
  int at = 0,
  bool explicit = false,
  String sender = 'VM-HDFCBK',
}) =>
    ParsedTransaction(
      amountMinor: amount,
      currency: 'INR',
      type: type,
      bankName: 'HDFC Bank',
      accountLast4: last4,
      accountKind: AccountKind.account,
      merchant: merchant,
      upiId: null,
      referenceNumber: ref,
      channel: Channel.upi,
      balanceMinor: balance,
      availableLimitMinor: null,
      transactionTime: _t0 + at,
      hasExplicitTime: explicit,
      category: Category.other,
      source: source,
      sender: sender,
      messageTimestamp: _t0 + at,
      confidence: 0.9,
      transactionHash: TransactionHasher.hash(
        amount,
        type,
        last4,
        civilDateOf(_t0 + at, const Duration(hours: 5, minutes: 30)),
        ref,
      ),
    );

class _Store extends DedupLookup {
  final rows = <StoredTransaction>[];
  final hashes = <String, int>{};
  int next = 1;

  Future<DedupDecision> add(ParsedTransaction t) async {
    final d = await DuplicateMatcher.decide(t, this);
    if (d is Duplicate) {
      final i = rows.indexWhere((r) => r.id == d.existingId);
      rows[i] = rows[i].copyWith(
        sources: {...rows[i].sources, sourceKey(t.source)},
        referenceNumber: rows[i].referenceNumber ?? t.referenceNumber,
        merchant: rows[i].merchant ?? t.merchant,
        appSenders: {
          ...rows[i].appSenders,
          if (t.source == Source.app) t.sender.toLowerCase(),
        },
      );
      hashes[t.transactionHash] = d.existingId;
    } else {
      final id = next++;
      rows.add(
        StoredTransaction(
          id: id,
          amountMinor: t.amountMinor,
          type: t.type,
          accountLast4: t.accountLast4,
          merchant: t.merchant,
          referenceNumber: t.referenceNumber,
          transactionTime: t.transactionTime,
          sources: {sourceKey(t.source)},
          balanceMinor: t.balanceMinor,
          hasExplicitTime: t.hasExplicitTime,
          appSenders: {if (t.source == Source.app) t.sender.toLowerCase()},
        ),
      );
      // A flagged row is stored under its own hash, as the ledger does.
      if (d is NewTransaction) hashes[t.transactionHash] = id;
    }
    return d;
  }

  @override
  Future<List<StoredTransaction>> byReference(String r) async => [
        for (final s in rows)
          if (DuplicateMatcher.refsEqual(s.referenceNumber, r)) s,
      ];

  @override
  Future<StoredTransaction?> byHash(String h) async {
    final id = hashes[h];
    return id == null ? null : rows.firstWhere((r) => r.id == id);
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

void main() {
  group('references (FR-07-19)', () {
    test('T01 one reference from an SMS and an email merges', () async {
      final s = _Store();
      await s.add(_tx(amount: 50000, ref: '612345678901'));
      final d = await s.add(
        _tx(
          amount: 50000,
          ref: '612345678901',
          source: Source.email,
          at: 20 * _min,
        ),
      );
      expect(d, isA<Duplicate>());
      expect(s.rows, hasLength(1));
    });

    test('T02 a prefixed statement reference merges within 96 hours', () async {
      final s = _Store();
      await s.add(_tx(amount: 50000, ref: '612345678901'));
      final d = await s.add(
        _tx(
          amount: 50000,
          ref: 'UPI612345678901',
          source: Source.statement,
          last4: null,
          at: 80 * _hour,
        ),
      );
      expect(d, isA<Duplicate>());
    });

    test('T03 the same reference nine days apart is left to the user',
        () async {
      final s = _Store();
      await s.add(_tx(amount: 50000, ref: '612345678901'));
      final d = await s
          .add(_tx(amount: 50000, ref: '612345678901', at: 9 * 24 * _hour));
      expect(d, isA<PossibleDuplicate>());
      expect((d as PossibleDuplicate).reason, contains('9 days apart'));
    });

    test('the same reference on different accounts is left to the user',
        () async {
      final s = _Store();
      await s.add(_tx(amount: 50000, ref: '612345678901'));
      final d = await s.add(
        _tx(amount: 50000, ref: '612345678901', last4: '9999', at: 5 * _min),
      );
      expect(d, isA<PossibleDuplicate>());
    });

    test('T04 short cheque numbers say nothing', () async {
      final s = _Store();
      await s.add(_tx(amount: 100000, ref: '000123', last4: '1111'));
      final d = await s
          .add(_tx(amount: 100000, ref: '123', last4: '2222', at: 10 * _min));
      expect(d, isA<NewTransaction>());
    });

    test('T05 the same reference on money coming back is not the same',
        () async {
      final s = _Store();
      await s.add(_tx(amount: 75000, ref: '612345678901'));
      final d = await s.add(
        _tx(
          amount: 75000,
          ref: '612345678901',
          type: TransactionType.credit,
          at: 24 * _hour,
        ),
      );
      expect(d, isA<NewTransaction>());
      expect(s.rows, hasLength(2));
    });

    test('references compare after normalising', () {
      expect(
        DuplicateMatcher.normalizeReference('  00526812 34 0020'),
        '526812340020',
      );
      expect(DuplicateMatcher.normalizeReference('12345'), isNull);
      expect(DuplicateMatcher.normalizeReference('111111'), isNull);
      expect(
        DuplicateMatcher.refsEqual('612345678901', 'upi-612345678901'),
        isTrue,
      );
      expect(
        DuplicateMatcher.refsEqual('612345678901', '612345678902'),
        isFalse,
      );
      expect(DuplicateMatcher.refsEqual('abc', 'abc'), isTrue);
    });
  });

  group('two payment apps for one payment (FR-07-20)', () {
    test('T07 a bank app and Google Pay within minutes merge', () async {
      final s = _Store();
      await s.add(
        _tx(
          amount: 25000,
          source: Source.app,
          sender: 'Google Pay',
          last4: null,
          merchant: 'Raju',
        ),
      );
      final d = await s.add(
        _tx(
          amount: 25000,
          source: Source.app,
          sender: 'HDFC Bank',
          last4: null,
          merchant: 'Raju',
          at: 1 * _min,
        ),
      );
      expect(d, isA<Duplicate>());
      expect(s.rows.single.appSenders, {'google pay', 'hdfc bank'});
    });

    test('two apps naming different people are two payments', () async {
      final s = _Store();
      await s.add(
        _tx(
          amount: 25000,
          source: Source.app,
          sender: 'Google Pay',
          last4: null,
          merchant: 'Raju',
        ),
      );
      final d = await s.add(
        _tx(
          amount: 25000,
          source: Source.app,
          sender: 'PhonePe',
          last4: null,
          merchant: 'Sita',
          at: 1 * _min,
        ),
      );
      expect(d, isA<NewTransaction>());
    });

    test('T09 the same app minutes apart stays two payments', () async {
      final s = _Store();
      await s.add(
        _tx(amount: 1000, source: Source.app, sender: 'Paytm', last4: null),
      );
      final d = await s.add(
        _tx(
          amount: 1000,
          source: Source.app,
          sender: 'Paytm',
          last4: null,
          at: 155 * 1000,
        ),
      );
      expect(d, isA<NewTransaction>());
    });
  });

  group('stated balances (FR-07-21)', () {
    test('T18 balances a step of the amount apart are two payments, no review',
        () async {
      final s = _Store();
      await s.add(_tx(amount: 2000, balance: 98000));
      final d = await s.add(_tx(amount: 2000, balance: 96000, at: 2 * _min));
      expect(d, isA<NewTransaction>());
      expect(s.rows, hasLength(2));
    });

    test('T19 an equal balance is one transaction told twice', () async {
      final s = _Store();
      await s.add(_tx(amount: 2000, balance: 98000));
      final d = await s.add(_tx(amount: 2000, balance: 98000, at: 30 * _min));
      expect(d, isA<Duplicate>());
      expect(s.rows, hasLength(1));
    });

    test('a credit step works the same way', () async {
      final s = _Store();
      await s.add(
        _tx(amount: 5000, type: TransactionType.credit, balance: 100000),
      );
      final d = await s.add(
        _tx(
          amount: 5000,
          type: TransactionType.credit,
          balance: 105000,
          at: 3 * _min,
        ),
      );
      expect(d, isA<NewTransaction>());
    });

    test('balances that explain nothing change nothing', () async {
      final s = _Store();
      await s.add(_tx(amount: 2000, balance: 98000));
      final d = await s.add(_tx(amount: 2000, balance: 50000, at: 6 * _min));
      // Same source, same hash, no reference: the user decides, as before.
      expect(d, isA<PossibleDuplicate>());
    });
  });

  group('printed times (FR-07-21)', () {
    test('T20 two messages printing times three minutes apart are two',
        () async {
      final s = _Store();
      await s.add(_tx(amount: 2000, explicit: true));
      final d = await s.add(_tx(amount: 2000, explicit: true, at: 3 * _min));
      expect(d, isA<NewTransaction>());
    });

    test('T21 with no printed times the same amount minutes apart is reviewed',
        () async {
      final s = _Store();
      await s.add(_tx(amount: 2000));
      final d = await s.add(_tx(amount: 2000, at: 6 * _min));
      expect(d, isA<PossibleDuplicate>());
    });

    test('an SMS and an email still merge when their printed times differ',
        () async {
      final s = _Store();
      await s.add(_tx(amount: 45000, explicit: true, merchant: 'Swiggy'));
      final d = await s.add(
        _tx(
          amount: 45000,
          explicit: true,
          source: Source.email,
          merchant: 'Swiggy',
          at: 2 * _min,
        ),
      );
      expect(d, isA<Duplicate>());
    });
  });

  group('late mail (FR-07-22)', () {
    test('T33 an email the next afternoon is a review, not a silent row',
        () async {
      final s = _Store();
      await s.add(_tx(amount: 249900, merchant: 'Amazon'));
      final d = await s.add(
        _tx(
          amount: 249900,
          source: Source.email,
          merchant: 'Amazon',
          at: 19 * _hour,
        ),
      );
      expect(d, isA<PossibleDuplicate>());
      expect(
        (d as PossibleDuplicate).reason,
        'Same amount from SMS and email on consecutive days',
      );
    });

    test('T34 a day and a quarter later is two payments', () async {
      final s = _Store();
      await s.add(_tx(amount: 249900, merchant: 'Amazon'));
      final d = await s.add(
        _tx(
          amount: 249900,
          source: Source.email,
          merchant: 'Amazon',
          at: 26 * _hour,
        ),
      );
      expect(d, isA<NewTransaction>());
    });

    test('different payees a day apart are not reviewed', () async {
      final s = _Store();
      await s.add(_tx(amount: 249900, merchant: 'Amazon'));
      final d = await s.add(
        _tx(
          amount: 249900,
          source: Source.email,
          merchant: 'Flipkart',
          at: 19 * _hour,
        ),
      );
      expect(d, isA<NewTransaction>());
    });
  });

  group('regressions', () {
    test('T35 different accounts stay two', () async {
      final s = _Store();
      await s.add(_tx(amount: 25000));
      final d = await s.add(
        _tx(amount: 25000, source: Source.email, last4: '5678', at: 5 * _min),
      );
      expect(d, isA<NewTransaction>());
    });

    test('T36 money in and money out of one amount are two', () async {
      final s = _Store();
      await s.add(_tx(amount: 25000));
      final d = await s.add(
        _tx(amount: 25000, type: TransactionType.credit, at: 1 * _min),
      );
      expect(d, isA<NewTransaction>());
    });
  });
}

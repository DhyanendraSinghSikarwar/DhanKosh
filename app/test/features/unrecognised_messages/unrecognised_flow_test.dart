// F-38: the review queue, learned senders and adding a queued message
// (FR-38-03..11). Every message is synthetic.
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/unrecognised_messages/data/unrecognised_repository_impl.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/domain/usecases/add_from_unrecognised.dart';
import 'package:hisaab/features/unrecognised_messages/domain/usecases/offer_unrecognised.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/test_env.dart';

const int _min = 60000;
const int _day = Duration.millisecondsPerDay;

NewUnrecognised _sms(
  String body, {
  String sender = 'VM-NEWBNK-S',
  String id = 'sms:1',
  int at = 1000000,
}) =>
    NewUnrecognised(
      source: UnrecognisedSource.sms,
      sender: sender,
      sourceMessageId: id,
      body: body,
      receivedAt: at,
    );

const _debit =
    'Rs.1,250.00 debited from A/c XX4821 on 05-11-26 to ZOMATO. Avl bal Rs.9,400.50';

void main() {
  late TestEnv env;
  late UnrecognisedRepositoryImpl repo;
  late OfferUnrecognised offer;
  var now = 5000000;

  setUp(() {
    env = TestEnv();
    now = 5000000;
    repo = UnrecognisedRepositoryImpl(env.db, now: () => now);
    offer = OfferUnrecognised(repo);
  });
  tearDown(() => env.close());

  group('the queue (FR-38-04, FR-38-05)', () {
    test('a message is queued once; the same one again is not', () async {
      final id = await repo.offer(_sms(_debit));
      expect(id, isNotNull);
      expect(await repo.offer(_sms(_debit)), isNull);
      // Same words, new id, while the first still waits: still one row.
      expect(await repo.offer(_sms(_debit, id: 'sms:2', at: 9000000)), isNull);
      expect((await repo.watchFresh().first).length, 1);
      expect(await repo.watchFreshCount().first, 1);
    });

    test('a handled message returns when the same words come later', () async {
      final id = (await repo.offer(_sms(_debit)))!;
      await repo.dismiss(id);
      // Seconds later: the same alert delivered twice.
      expect(
        await repo.offer(_sms(_debit, id: 'sms:2', at: 1000000 + _min)),
        isNull,
      );
      // An hour later: another payment.
      final again = await repo.offer(
        _sms(_debit, id: 'sms:3', at: 1000000 + 60 * _min),
      );
      expect(again, id);
      final m = (await repo.byId(id))!;
      expect(m.status, UnrecognisedStatus.fresh);
      expect(m.sourceMessageId, 'sms:3');
    });

    test('dismiss can be undone while the text is kept', () async {
      final id = (await repo.offer(_sms(_debit)))!;
      await repo.dismiss(id);
      expect(await repo.watchFreshCount().first, 0);
      await repo.restore(id);
      expect(await repo.watchFreshCount().first, 1);
    });

    test('switching a sender off ignores its waiting and future messages',
        () async {
      final id = (await repo.offer(_sms(_debit)))!;
      final key = SenderKey.of(UnrecognisedSource.sms, 'VM-NEWBNK-S');
      expect(await repo.ignoreSender(key), 1);
      expect((await repo.byId(id))!.status, UnrecognisedStatus.ignored);
      expect(
        await repo.offer(_sms('INR 80 debited from a/c 1234', id: 'sms:9')),
        isNull,
      );
      await repo.forget(key);
      expect(
        await repo.offer(_sms('INR 80 debited from a/c 1234', id: 'sms:9')),
        isNotNull,
      );
    });

    test('purge empties old text and keeps a tombstone', () async {
      final id = (await repo.offer(_sms(_debit)))!;
      now += 31 * _day;
      expect(await repo.purge(), 1);
      final m = (await repo.byId(id))!;
      expect(m.status, UnrecognisedStatus.expired);
      expect(m.body, isEmpty);
      // An emptied row cannot be restored, and no suggestion is made.
      await repo.restore(id);
      expect((await repo.byId(id))!.status, UnrecognisedStatus.expired);
      expect(m.suggestion(), isNull);
    });
  });

  group('what is worth queueing (FR-38-03)', () {
    test('an unknown sender is queued only for a payment it describes',
        () async {
      expect(
        await offer.sms(_sms(_debit), requireLearned: false),
        OfferResult.queued,
      );
      expect(
        await offer.sms(
          _sms('482910 is your OTP to pay Rs 1,100 at ZOMATO', id: 'sms:2'),
          requireLearned: false,
        ),
        OfferResult.skipped,
      );
      expect(
        await offer.sms(
          _sms('Hello from your bank', id: 'sms:3'),
          requireLearned: false,
        ),
        OfferResult.skipped,
      );
    });

    test('live, an unknown sender is never queued; a learned one is', () async {
      expect(
        await offer.sms(_sms(_debit), requireLearned: true),
        OfferResult.skipped,
      );
      await repo.learn(SenderKey.of(UnrecognisedSource.sms, 'VM-NEWBNK-S'));
      expect(
        await offer.sms(_sms(_debit), requireLearned: true),
        OfferResult.queuedFromLearned,
      );
    });

    test('a clear notification is booked at once; a vague one waits', () async {
      final booked = <ConfirmedPayment>[];
      final auto = OfferUnrecognised(
        repo,
        autoAdd: (m, c) async => booked.add(c),
      );
      final clear = await auto.notification(
        const NewUnrecognised(
          source: UnrecognisedSource.app,
          sender: 'PhonePe',
          sourceMessageId: 'app:clear',
          body: 'Paid INR 250 to Ravi Kumar via UPI. Ref 612345678901',
          receivedAt: 1000000,
        ),
      );
      expect(clear, OfferResult.booked);
      expect(booked.single.amountMinor, 25000);
      expect(booked.single.type, TransactionType.debit);
      expect(booked.single.merchant, 'Ravi Kumar');

      final vague = await auto.notification(
        const NewUnrecognised(
          source: UnrecognisedSource.app,
          sender: 'PhonePe',
          sourceMessageId: 'app:vague',
          body: 'Completed: INR 90 via UPI',
          receivedAt: 1000001,
        ),
      );
      expect(vague, OfferResult.queued);
      expect(booked, hasLength(1));
    });

    test('a payment app notification with only an amount is queued', () async {
      final r = await offer.notification(
        const NewUnrecognised(
          source: UnrecognisedSource.app,
          sender: 'PhonePe',
          sourceMessageId: 'app:abc',
          body: 'Completed: INR 250 to Ravi Kumar via UPI',
          receivedAt: 1000000,
        ),
      );
      expect(r, OfferResult.queued);
      final m = (await repo.watchFresh().first).single;
      final s = m.suggestion(loose: true)!;
      expect(s.directionGuessed, isTrue);
      expect(s.amountMinor, 25000);
    });
  });

  group('sender keys (FR-38-07)', () {
    test('operator prefix and DLT suffix do not make a new sender', () {
      String k(String s) => SenderKey.of(UnrecognisedSource.sms, s);
      expect(k('JD-ABCBNK-S'), k('VM-ABCBNK'));
      expect(k('VM-ABCBNK'), k('abcbnk'));
      expect(
        SenderKey.of(UnrecognisedSource.app, 'PhonePe'),
        'app:phonepe',
      );
    });

    test('a learned account fits only when the text does not point elsewhere',
        () {
      const p = SenderPref(
        senderKey: 'X',
        ignored: false,
        learnedAt: 0,
        bankName: 'ABC Bank',
        last4: '4821',
        currency: 'INR',
      );
      expect(p.accountFits(), isTrue);
      expect(p.accountFits(textLast4: '4821', textCurrency: 'INR'), isTrue);
      expect(p.accountFits(textLast4: '9999'), isFalse);
      expect(p.accountFits(textCurrency: 'USD'), isFalse);
    });
  });

  group('adding a queued message (FR-38-07, FR-38-11)', () {
    test('it becomes one transaction, teaches the sender and books once',
        () async {
      final id = (await repo.offer(_sms(_debit)))!;
      final m = (await repo.byId(id))!;
      final add = AddFromUnrecognised(queue: repo, ledger: env.txs);
      final r = await add(
        m,
        const ConfirmedPayment(
          amountMinor: 125000,
          type: TransactionType.debit,
          timestamp: 1790310600000,
          merchant: 'Zomato',
          category: Category.food,
          accountBank: 'ABC Bank',
          accountLast4: '4821',
        ),
      );
      expect(r.outcome, IngestOutcome.inserted);
      expect(await env.count('transactions'), 1);
      expect((await repo.byId(id))!.status, UnrecognisedStatus.added);
      expect((await repo.byId(id))!.transactionId, r.transactionId);

      final p = (await repo.pref(m.senderKey))!;
      expect(p.ignored, isFalse);
      expect(p.last4, '4821');

      // The same message read again, as a parser would after a rescan, is the
      // same message: not booked twice.
      final again = await env.txs.addFromMessage(
        source: Source.sms,
        sourceMessageId: 'sms:1',
        sender: 'VM-NEWBNK-S',
        rawText: _debit,
        amountMinor: 125000,
        type: TransactionType.debit,
        timestamp: 1790310600000,
      );
      expect(again.outcome, IngestOutcome.skipped);
      expect(await env.count('transactions'), 1);
    });

    test('the learned account is dropped when the text names other digits',
        () async {
      final id = (await repo.offer(_sms(_debit)))!;
      final m = (await repo.byId(id))!;
      await AddFromUnrecognised(queue: repo, ledger: env.txs)(
        m,
        const ConfirmedPayment(
          amountMinor: 125000,
          type: TransactionType.debit,
          timestamp: 1790310600000,
          accountBank: 'Other Bank',
          accountLast4: '7777',
        ),
      );
      final p = (await repo.pref(m.senderKey))!;
      expect(p.last4, isNull);
      expect(p.ignored, isFalse);
    });

    test('a notification is added without teaching a sender', () async {
      final id = (await repo.offer(
        const NewUnrecognised(
          source: UnrecognisedSource.app,
          sender: 'PhonePe',
          sourceMessageId: 'app:abc',
          body: 'Completed: INR 250 to Ravi Kumar via UPI',
          receivedAt: 1790310600000,
        ),
      ))!;
      final m = (await repo.byId(id))!;
      final r = await AddFromUnrecognised(queue: repo, ledger: env.txs)(
        m,
        const ConfirmedPayment(
          amountMinor: 25000,
          type: TransactionType.debit,
          timestamp: 1790310600000,
          merchant: 'Ravi Kumar',
          channel: Channel.upi,
        ),
      );
      expect(r.outcome, IngestOutcome.inserted);
      expect(await repo.pref(m.senderKey), isNull);
    });
  });
}

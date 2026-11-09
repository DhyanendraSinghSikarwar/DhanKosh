import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_repository.dart';
import 'package:hisaab/features/unrecognised_messages/domain/usecases/add_from_unrecognised.dart';
import 'package:parser_core/parser_core.dart';

/// What [OfferUnrecognised] did with a message.
enum OfferResult {
  /// Queued, or an earlier row revived.
  queued,

  /// Queued from a sender the user taught the app: worth an alert.
  queuedFromLearned,

  /// A clear payment-app notification, added to the ledger at once.
  booked,

  /// Not queued: nothing that looks like a payment, or already seen.
  skipped,
}

/// Decides whether a message nothing could read is worth the user's look, and
/// queues it (FR-38-03, FR-38-04).
///
/// An SMS from an unknown sender is queued only when the generic reader finds
/// a payment in it. An SMS from a sender the user taught the app is queued at
/// any score (`requireLearned` false also lets unknown senders in, for the
/// user's own inbox scan). A payment app's notification the strict parser
/// could not read is queued when it carries an amount, with the direction
/// assumed and marked.
class OfferUnrecognised {
  /// Creates the use case.
  const OfferUnrecognised(this._repo, {this.autoAdd});

  final UnrecognisedRepository _repo;

  /// Adds a clear notification to the ledger (FR-38-14); null queues all.
  final Future<void> Function(UnrecognisedMessage m, ConfirmedPayment c)?
      autoAdd;

  /// Offers an SMS.
  Future<OfferResult> sms(
    NewUnrecognised m, {
    required bool requireLearned,
  }) async =>
      (await smsWithId(m, requireLearned: requireLearned)).$1;

  /// Offers an SMS; also gives the queued row's id when there is one.
  Future<(OfferResult, int?)> smsWithId(
    NewUnrecognised m, {
    required bool requireLearned,
  }) async {
    final key = SenderKey.of(m.source, m.sender);
    final p = await _repo.pref(key);
    if (p != null && p.ignored) return (OfferResult.skipped, null);
    final learned = p != null;
    if (requireLearned && !learned) return (OfferResult.skipped, null);
    if (GenericExtractor.read(m.sender, m.body) == null) {
      return (OfferResult.skipped, null);
    }
    final id = await _repo.offer(m);
    if (id == null) return (OfferResult.skipped, null);
    return (learned ? OfferResult.queuedFromLearned : OfferResult.queued, id);
  }

  /// Offers a payment-app notification the strict parser rejected.
  ///
  /// A notification that states its direction and scores at least
  /// [GenericExtractor.autoBookAt] is added to the ledger at once, so the
  /// payment shows in Transactions without a tap (FR-38-14). The rest wait in
  /// the queue.
  Future<OfferResult> notification(NewUnrecognised m) async {
    final s = GenericExtractor.readLoose(m.sender, m.body);
    if (s == null) return OfferResult.skipped;
    final id = await _repo.offer(m);
    if (id == null) return OfferResult.skipped;
    final add = autoAdd;
    if (add != null &&
        !s.directionGuessed &&
        s.confidence >= GenericExtractor.autoBookAt) {
      final row = await _repo.byId(id);
      if (row != null) {
        await add(
          row,
          ConfirmedPayment(
            amountMinor: s.amountMinor,
            type: s.type,
            timestamp: m.receivedAt,
            currency: s.currency,
            merchant: s.merchant,
            upiId: s.upiId,
            category: s.category,
            reference: s.reference,
            channel: s.channel,
          ),
        );
        return OfferResult.booked;
      }
    }
    return OfferResult.queued;
  }
}

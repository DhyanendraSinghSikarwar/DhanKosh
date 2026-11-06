import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';

/// The review queue and the senders the user taught the app (F-38).
abstract interface class UnrecognisedRepository {
  /// Messages waiting for the user, newest first (FR-38-04).
  Stream<List<UnrecognisedMessage>> watchFresh();

  /// How many are waiting.
  Stream<int> watchFreshCount();

  /// One message, or null.
  Future<UnrecognisedMessage?> byId(int id);

  /// Queues [m]; returns its row id, or null when it is not queued: its sender
  /// is switched off, it is already waiting, or it repeats a handled message
  /// within 2 minutes. An identical message later revives the handled row, so
  /// a second payment from an app with no reference is offered again
  /// (FR-38-05).
  Future<int?> offer(NewUnrecognised m);

  /// Marks the message added as [transactionId].
  Future<void> markAdded(int id, {int? transactionId});

  /// Dismisses the message; the text is kept for 30 days so [restore] works.
  Future<void> dismiss(int id);

  /// Undoes a dismissal.
  Future<void> restore(int id);

  /// Switches the sender off: its waiting messages are marked ignored and
  /// later ones are not queued (FR-38-08).
  Future<void> ignoreSender(String senderKey);

  /// Teaches the app [senderKey]: later messages are offered at any score and
  /// pre-filled with the account last used (FR-38-07).
  Future<void> learn(
    String senderKey, {
    String? bankName,
    String? last4,
    String? currency,
  });

  /// Forgets a learned or ignored sender (FR-38-09).
  Future<void> forget(String senderKey);

  /// The preference for [senderKey], or null.
  Future<SenderPref?> pref(String senderKey);

  /// Every learned or ignored sender, newest first.
  Stream<List<SenderPref>> watchPrefs();

  /// Empties the text of messages past the retention window; returns rows
  /// changed (FR-38-10).
  Future<int> purge();
}

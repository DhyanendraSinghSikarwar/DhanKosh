import 'package:parser_core/parser_core.dart';

/// Where a queued message came from.
enum UnrecognisedSource {
  /// A bank SMS no parser claims.
  sms,

  /// A payment-app notification the strict parser could not read.
  app;

  /// The stored name.
  String get key => name.toUpperCase();

  /// The source for a stored [key].
  static UnrecognisedSource fromKey(String key) =>
      key == 'APP' ? UnrecognisedSource.app : UnrecognisedSource.sms;
}

/// What became of a queued message (FR-38-05).
enum UnrecognisedStatus {
  /// Waiting for the user.
  fresh,

  /// Added as a transaction.
  added,

  /// Dismissed by the user; can be undone while the text is kept.
  dismissed,

  /// Its sender was switched off.
  ignored,

  /// Left waiting past the retention window.
  expired;

  /// The stored name.
  String get key => name.toUpperCase();

  /// The status for a stored [key].
  static UnrecognisedStatus fromKey(String key) => values.firstWhere(
        (s) => s.key == key,
        orElse: () => UnrecognisedStatus.expired,
      );
}

/// A message waiting in, or handled by, the review queue (FR-38-04).
class UnrecognisedMessage {
  /// Creates a message.
  const UnrecognisedMessage({
    required this.id,
    required this.source,
    required this.sender,
    required this.senderKey,
    required this.sourceMessageId,
    required this.body,
    required this.receivedAt,
    required this.status,
    this.transactionId,
  });

  /// Row id.
  final int id;

  /// SMS or payment app.
  final UnrecognisedSource source;

  /// SMS header, or the app's display name.
  final String sender;

  /// Normalised sender, see [SenderKey].
  final String senderKey;

  /// Id of the message in its source, so adding it books it once.
  final String sourceMessageId;

  /// The text; empty once the retention window has passed.
  final String body;

  /// Arrival time, epoch ms.
  final int receivedAt;

  /// Current status.
  final UnrecognisedStatus status;

  /// The transaction it became, when added.
  final int? transactionId;

  /// The "Looks like" reading, or null when none can be made or the text is
  /// gone. [learned] lowers the bar to any score (FR-38-03).
  GenericSuggestion? suggestion({bool learned = false, bool loose = false}) {
    if (body.isEmpty) return null;
    final s = loose
        ? GenericExtractor.readLoose(sender, body)
        : GenericExtractor.read(sender, body);
    if (s == null) return null;
    return learned || s.showsSuggestion || s.directionGuessed ? s : null;
  }
}

/// A message about to be queued.
class NewUnrecognised {
  /// Creates a new queue entry.
  const NewUnrecognised({
    required this.source,
    required this.sender,
    required this.sourceMessageId,
    required this.body,
    required this.receivedAt,
  });

  /// SMS or payment app.
  final UnrecognisedSource source;

  /// SMS header, or the app's display name.
  final String sender;

  /// Id of the message in its source.
  final String sourceMessageId;

  /// The text.
  final String body;

  /// Arrival time, epoch ms.
  final int receivedAt;
}

/// A sender the user taught the app, or switched off (FR-38-07, FR-38-08).
class SenderPref {
  /// Creates a preference.
  const SenderPref({
    required this.senderKey,
    required this.ignored,
    required this.learnedAt,
    this.bankName,
    this.last4,
    this.currency,
  });

  /// Normalised sender.
  final String senderKey;

  /// True when the user switched the sender off; false when learned.
  final bool ignored;

  /// When it was set, epoch ms.
  final int learnedAt;

  /// Bank of the account last used for this sender.
  final String? bankName;

  /// Last digits of that account.
  final String? last4;

  /// Currency last used.
  final String? currency;

  /// The account to pre-fill for a message naming [textLast4] in
  /// [textCurrency]: only when the text does not point elsewhere (FR-38-07).
  bool accountFits({String? textLast4, String? textCurrency}) {
    if (last4 == null) return false;
    if (textLast4 != null && textLast4 != last4) return false;
    if (currency != null && textCurrency != null && textCurrency != currency) {
      return false;
    }
    return true;
  }
}

/// The key under which a sender is remembered (FR-38-07): an SMS header loses
/// its operator prefix and DLT suffix, so `JD-ABCBNK-S`, `VM-ABCBNK` and
/// `abcbnk` are one sender; an app is its lower-cased name.
abstract final class SenderKey {
  /// The key for [sender] arriving through [source].
  static String of(UnrecognisedSource source, String sender) {
    final s = sender.trim();
    if (source == UnrecognisedSource.app) return 'app:${s.toLowerCase()}';
    final header = SenderKeys.smsHeader(s);
    return header.isEmpty ? s.toUpperCase() : header;
  }
}

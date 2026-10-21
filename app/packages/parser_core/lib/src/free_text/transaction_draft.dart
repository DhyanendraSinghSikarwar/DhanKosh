import 'package:parser_core/src/model/model.dart';

/// What could be read from text that has no bank sender: a screenshot, or a
/// payment app's notification. Any field may be missing.
class TransactionDraft {
  /// Creates a draft.
  const TransactionDraft({
    required this.amountMinor,
    required this.currency,
    required this.type,
    required this.merchant,
    required this.upiId,
    required this.reference,
    required this.bankName,
    required this.last4,
    required this.accountKind,
    required this.channel,
    required this.category,
    required this.time,
    required this.hasExplicitTime,
  });

  /// Amount in paise.
  final int? amountMinor;

  /// ISO currency code.
  final String currency;

  /// Direction, if the text gave one.
  final TransactionType? type;

  /// Display merchant.
  final String? merchant;

  /// UPI id.
  final String? upiId;

  /// Reference number.
  final String? reference;

  /// Bank named in the text.
  final String? bankName;

  /// Last digits of the account or card.
  final String? last4;

  /// Account or card.
  final AccountKind accountKind;

  /// Payment rail.
  final Channel channel;

  /// Guessed category.
  final Category category;

  /// Transaction time, epoch ms.
  final int time;

  /// Whether the text stated a time of day.
  final bool hasExplicitTime;
}

/// A notification outcome: the transaction, or a short generic [skipReason]
/// (never the text) for the activity log.
class NotificationRead {
  /// Creates an outcome.
  const NotificationRead(this.tx, this.skipReason);

  /// The transaction, if the notification was a payment.
  final ParsedTransaction? tx;

  /// Why it was skipped.
  final String? skipReason;
}

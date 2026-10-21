import 'package:parser_core/parser_core.dart';

/// One ledger row. Money in paise, times in epoch ms (FR-08).
class LedgerTx {
  const LedgerTx({
    required this.id,
    required this.amountMinor,
    required this.currency,
    required this.type,
    required this.bankName,
    required this.accountKind,
    required this.channel,
    required this.timestamp,
    required this.hasExplicitTime,
    required this.category,
    required this.transactionHash,
    required this.confidence,
    required this.needsReview,
    required this.createdAt,
    this.accountLast4,
    this.accountId,
    this.merchant,
    this.upiId,
    this.referenceNumber,
    this.balanceMinor,
    this.availableLimitMinor,
    this.subcategory,
    this.customCategoryId,
    this.duplicateOfId,
    this.reviewReason,
    this.note,
    this.inrMinor,
  });

  final int id;
  final int amountMinor;
  final String currency;
  final TransactionType type;
  final String bankName;
  final String? accountLast4;
  final AccountKind accountKind;
  final int? accountId;
  final String? merchant;
  final String? upiId;
  final String? referenceNumber;
  final Channel channel;
  final int? balanceMinor;
  final int? availableLimitMinor;
  final int timestamp;
  final bool hasExplicitTime;
  final Category category;
  final String? subcategory;
  final int? customCategoryId;
  final String transactionHash;
  final double confidence;
  final bool needsReview;
  final int? duplicateOfId;
  final String? reviewReason;
  final String? note;
  final int createdAt;
  final int? inrMinor;

  /// Merchant, or the bank when none (By-merchant grouping, FR-08-04).
  String get title => merchant ?? bankName;
}

/// A message behind a ledger row.
class TxSourceRow {
  const TxSourceRow({
    required this.id,
    required this.transactionId,
    required this.source,
    required this.sourceMessageId,
    required this.sender,
    required this.parsedHash,
    required this.receivedAt,
    this.rawText,
    this.subject,
  });

  final int id;
  final int transactionId;
  final Source source;
  final String sourceMessageId;
  final String sender;
  final String parsedHash;
  final String? rawText;
  final int receivedAt;
  final String? subject;
}

/// A flagged row and the row it may duplicate (null if that one is gone).
class ReviewPair {
  const ReviewPair(this.flagged, this.target);
  final LedgerTx flagged;
  final LedgerTx? target;
}

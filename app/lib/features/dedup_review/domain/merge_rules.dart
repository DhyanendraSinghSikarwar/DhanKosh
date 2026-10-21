import 'package:hisaab/features/dedup_review/domain/dedup_policy.dart';
import 'package:parser_core/parser_core.dart';

/// Fields of a stored row after folding in another message (memory 07 3.5).
class MergedFields {
  const MergedFields({
    required this.amountMinor,
    required this.merchant,
    required this.upiId,
    required this.referenceNumber,
    required this.balanceMinor,
    required this.availableLimitMinor,
    required this.accountLast4,
    required this.type,
    required this.category,
    required this.timestamp,
    required this.hasExplicitTime,
    required this.confidence,
  });

  final int amountMinor;
  final String? merchant;
  final String? upiId;
  final String? referenceNumber;
  final int? balanceMinor;
  final int? availableLimitMinor;
  final String? accountLast4;
  final TransactionType type;
  final Category category;
  final int timestamp;
  final bool hasExplicitTime;
  final double confidence;
}

/// Keeps stored values and fills gaps from [tx] (FR-07-09).
MergedFields mergeInto(DedupCandidate c, ParsedTransaction tx) {
  var amount = c.amountMinor;
  if (c.amountMinor % 100 == 0 &&
      tx.amountMinor % 100 != 0 &&
      tx.amountMinor ~/ 100 == c.amountMinor ~/ 100 &&
      tx.currency == c.currency) {
    amount = tx.amountMinor;
  }

  final merchant = (isWeakMerchant(c.merchant) && !isWeakMerchant(tx.merchant))
      ? tx.merchant
      : (c.merchant ?? tx.merchant);

  var last4 = c.accountLast4;
  final inLast4 = tx.accountLast4;
  if (last4 == null || (inLast4 != null && inLast4.length > last4.length)) {
    last4 = inLast4 ?? last4;
  }

  final type =
      (c.type == TransactionType.debit && tx.type == TransactionType.investment)
          ? TransactionType.investment
          : c.type;

  final storedWeakCat =
      c.category == Category.other || c.category == Category.income;
  final inWeakCat =
      tx.category == Category.other || tx.category == Category.income;
  final category = (storedWeakCat && !inWeakCat) ? tx.category : c.category;

  var time = c.timestamp;
  if (tx.hasExplicitTime && !c.hasExplicitTime) time = tx.transactionTime;
  final statesBalance =
      tx.balanceMinor != null || tx.availableLimitMinor != null;
  if (statesBalance &&
      tx.source != Source.statement &&
      time > tx.transactionTime &&
      time - tx.transactionTime <= DedupPolicy.windowMillis) {
    time = tx.transactionTime;
  }

  return MergedFields(
    amountMinor: amount,
    merchant: merchant,
    upiId: c.upiId ?? tx.upiId,
    referenceNumber: c.referenceNumber ?? tx.referenceNumber,
    balanceMinor: c.balanceMinor ?? tx.balanceMinor,
    availableLimitMinor: c.availableLimitMinor ?? tx.availableLimitMinor,
    accountLast4: last4,
    type: type,
    category: category,
    timestamp: time,
    hasExplicitTime: c.hasExplicitTime || tx.hasExplicitTime,
    confidence: c.confidence > tx.confidence ? c.confidence : tx.confidence,
  );
}

/// A merchant that is an id, mostly digits or a generic UI phrase.
bool isWeakMerchant(String? m) {
  if (m == null || m.trim().isEmpty) return true;
  if (m.contains('@')) return true;
  final digits = RegExp('[0-9]').allMatches(m).length;
  if (digits * 2 > m.length) return true;
  return const {'payment', 'upi payment', 'paid', 'transaction', 'money sent'}
      .contains(m.trim().toLowerCase());
}

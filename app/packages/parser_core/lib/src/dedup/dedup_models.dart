import 'package:parser_core/src/model/model.dart';

/// The key under which a [Source] is stored in a transaction's source set:
/// the upper-case name ("SMS", "EMAIL", "APP", "SCREENSHOT", "MANUAL",
/// "STATEMENT"), as the Kotlin app stores it.
String sourceKey(Source source) => source.name.toUpperCase();

/// What the dedup layer knows about a stored transaction. [sources] holds the
/// source keys (see [sourceKey]) already attached.
class StoredTransaction {
  /// Creates a stored transaction.
  const StoredTransaction({
    required this.id,
    required this.amountMinor,
    required this.type,
    required this.accountLast4,
    required this.merchant,
    required this.referenceNumber,
    required this.transactionTime,
    required this.sources,
  });

  /// Row id.
  final int id;

  /// Amount in paise.
  final int amountMinor;

  /// Debit, credit, transfer or investment.
  final TransactionType type;

  /// Last digits of the account.
  final String? accountLast4;

  /// Merchant.
  final String? merchant;

  /// Reference number.
  final String? referenceNumber;

  /// Time, epoch ms.
  final int transactionTime;

  /// Source keys already attached.
  final Set<String> sources;

  /// A copy with the given fields replaced (a null argument keeps the field).
  StoredTransaction copyWith({
    String? accountLast4,
    String? merchant,
    String? referenceNumber,
    Set<String>? sources,
  }) =>
      StoredTransaction(
        id: id,
        amountMinor: amountMinor,
        type: type,
        accountLast4: accountLast4 ?? this.accountLast4,
        merchant: merchant ?? this.merchant,
        referenceNumber: referenceNumber ?? this.referenceNumber,
        transactionTime: transactionTime,
        sources: sources ?? this.sources,
      );
}

/// Why a duplicate was recognised.
enum MatchReason { reference, hash, fuzzy }

/// The matcher's verdict on an incoming message.
sealed class DedupDecision {
  const DedupDecision();
}

/// Same transaction: merge the incoming message into [existingId].
final class Duplicate extends DedupDecision {
  /// A duplicate of [existingId].
  const Duplicate(this.existingId, this.reason);

  /// Row to merge into.
  final int existingId;

  /// How it was recognised.
  final MatchReason reason;

  @override
  bool operator ==(Object other) =>
      other is Duplicate &&
      other.existingId == existingId &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(existingId, reason);

  @override
  String toString() => 'Duplicate($existingId, $reason)';
}

/// Probably the same transaction but not certain: store it flagged for the user
/// to merge or keep.
final class PossibleDuplicate extends DedupDecision {
  /// Possibly a duplicate of [existingId].
  const PossibleDuplicate(this.existingId, this.reason);

  /// Row it may duplicate.
  final int existingId;

  /// Review reason shown to the user.
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is PossibleDuplicate &&
      other.existingId == existingId &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(existingId, reason);

  @override
  String toString() => 'PossibleDuplicate($existingId, $reason)';
}

/// A transaction not seen before.
final class NewTransaction extends DedupDecision {
  /// The only value.
  const NewTransaction();

  @override
  bool operator ==(Object other) => other is NewTransaction;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'New';
}

/// The storage queries the matcher needs. The Drift implementation lives in the
/// dedup feature.
abstract class DedupLookup {
  /// Stored transactions with this reference number.
  Future<List<StoredTransaction>> byReference(String referenceNumber);

  /// The stored transaction with this hash, if any.
  Future<StoredTransaction?> byHash(String transactionHash);

  /// Transactions of exactly [amountMinor] with a time in [from, to].
  Future<List<StoredTransaction>> potentialDuplicates(
    int amountMinor,
    int from,
    int to,
  );

  /// Transactions with an amount in [minMinor]..[maxMinor] and a time in
  /// [from, to]. Used to match a rounded payment-app amount; override with a
  /// range query, the default asks once per paisa value.
  Future<List<StoredTransaction>> potentialDuplicatesInRange(
    int minMinor,
    int maxMinor,
    int from,
    int to,
  ) async {
    final out = <StoredTransaction>[];
    for (var a = minMinor; a <= maxMinor; a++) {
      out.addAll(await potentialDuplicates(a, from, to));
    }
    return out;
  }
}

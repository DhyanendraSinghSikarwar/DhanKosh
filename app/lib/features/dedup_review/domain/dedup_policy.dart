import 'package:parser_core/parser_core.dart' hide DedupDecision;

/// Why an incoming message was merged into a stored row (FR-07-02..06).
enum DuplicateReason { reference, hash, fuzzy }

/// A stored ledger row as the dedup rules see it (pure data, no storage).
class DedupCandidate {
  const DedupCandidate({
    required this.id,
    required this.amountMinor,
    required this.currency,
    required this.type,
    required this.timestamp,
    required this.hasExplicitTime,
    required this.transactionHash,
    required this.category,
    required this.confidence,
    required this.sources,
    this.referenceNumber,
    this.accountLast4,
    this.accountId,
    this.merchant,
    this.upiId,
    this.balanceMinor,
    this.availableLimitMinor,
    this.sourceHashes = const {},
  });

  final int id;
  final int amountMinor;
  final String currency;
  final TransactionType type;
  final int timestamp;
  final bool hasExplicitTime;
  final String transactionHash;
  final Category category;
  final double confidence;

  /// Sources of every message already merged into the row.
  final Set<Source> sources;

  /// Hashes of every message already merged into the row.
  final Set<String> sourceHashes;
  final String? referenceNumber;
  final String? accountLast4;
  final int? accountId;
  final String? merchant;
  final String? upiId;
  final int? balanceMinor;
  final int? availableLimitMinor;
}

/// Outcome of [DedupPolicy.decide].
sealed class DedupDecision {
  const DedupDecision();
}

/// No match: insert a new row.
class DedupNew extends DedupDecision {
  const DedupNew();
}

/// Same payment as [existingId]: merge.
class DedupDuplicate extends DedupDecision {
  const DedupDuplicate(this.existingId, this.reason);
  final int existingId;
  final DuplicateReason reason;
}

/// Uncertain: insert flagged for review.
class DedupPossible extends DedupDecision {
  const DedupPossible(this.existingId, this.reasonText);
  final int existingId;
  final String reasonText;
}

/// Duplicate decision of memory 07 section 3.3 (FR-07-02..06).
///
/// A thin adapter over parser_core's [DuplicateMatcher], the single matcher
/// shared with the Kotlin-parity tests. The repository loads one candidate
/// list and this class serves it to the matcher as an in-memory lookup.
class DedupPolicy {
  const DedupPolicy();

  static const int windowMillis = DuplicateMatcher.windowMillis;
  static const int reviewWindowMillis = DuplicateMatcher.reviewWindowMillis;
  static const int statementWindowMillis =
      DuplicateMatcher.statementWindowMillis;
  static const int roundedWindowMillis = DuplicateMatcher.roundedWindowMillis;

  /// Decides what to do with [tx] given nearby stored [candidates].
  Future<DedupDecision> decide(
    ParsedTransaction tx,
    List<DedupCandidate> candidates,
  ) async {
    final lookup = _CandidateLookup(candidates);
    final d = await DuplicateMatcher.decide(tx, lookup);
    return switch (d) {
      Duplicate(:final existingId, :final reason) => DedupDuplicate(
          existingId,
          switch (reason) {
            MatchReason.reference => DuplicateReason.reference,
            MatchReason.hash => DuplicateReason.hash,
            MatchReason.fuzzy => DuplicateReason.fuzzy,
          },
        ),
      PossibleDuplicate(:final existingId, :final reason) =>
        DedupPossible(existingId, reason),
      NewTransaction() => const DedupNew(),
    };
  }

  /// Equal, or one ends with the other ("123" vs "0123").
  static bool last4Match(String a, String b) =>
      DuplicateMatcher.last4Match(a, b);

  /// See [DuplicateMatcher.merchantsAgree].
  static bool merchantsAgree(String? a, String? b) =>
      DuplicateMatcher.merchantsAgree(a, b);
}

/// Serves the repository's pre-loaded candidates to [DuplicateMatcher].
class _CandidateLookup extends DedupLookup {
  _CandidateLookup(List<DedupCandidate> candidates)
      : _rows = [for (final c in candidates) _Row(c)];

  final List<_Row> _rows;

  @override
  Future<List<StoredTransaction>> byReference(String referenceNumber) async => [
        for (final r in _rows)
          if (r.stored.referenceNumber == referenceNumber) r.stored,
      ];

  // A row also owns the hashes of the messages merged into it.
  @override
  Future<StoredTransaction?> byHash(String transactionHash) async {
    for (final r in _rows) {
      if (r.candidate.transactionHash == transactionHash ||
          r.candidate.sourceHashes.contains(transactionHash)) {
        return r.stored;
      }
    }
    return null;
  }

  @override
  Future<List<StoredTransaction>> potentialDuplicates(
    int amountMinor,
    int from,
    int to,
  ) =>
      potentialDuplicatesInRange(amountMinor, amountMinor, from, to);

  @override
  Future<List<StoredTransaction>> potentialDuplicatesInRange(
    int minMinor,
    int maxMinor,
    int from,
    int to,
  ) async =>
      [
        for (final r in _rows)
          if (r.stored.amountMinor >= minMinor &&
              r.stored.amountMinor <= maxMinor &&
              r.stored.transactionTime >= from &&
              r.stored.transactionTime <= to)
            r.stored,
      ];
}

class _Row {
  _Row(this.candidate)
      : stored = StoredTransaction(
          id: candidate.id,
          amountMinor: candidate.amountMinor,
          type: candidate.type,
          accountLast4: candidate.accountLast4,
          merchant: candidate.merchant,
          // An empty reference is no reference (matches the stored form).
          referenceNumber: (candidate.referenceNumber?.isEmpty ?? true)
              ? null
              : candidate.referenceNumber,
          transactionTime: candidate.timestamp,
          sources: {for (final s in candidate.sources) sourceKey(s)},
        );

  final DedupCandidate candidate;
  final StoredTransaction stored;
}

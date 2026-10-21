import 'package:parser_core/parser_core.dart';

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

/// Duplicate decision rules of memory 07 section 3.3 (pure Dart).
///
/// Shaped like parser_core's `DuplicateMatcher` (decide over stored rows) so
/// the lead can swap the adapter; storage lookups are replaced by a candidate
/// list loaded once by the repository.
class DedupPolicy {
  const DedupPolicy();

  static const int windowMillis = 30 * 60 * 1000;
  static const int reviewWindowMillis = 12 * 3600 * 1000;
  static const int statementWindowMillis = 36 * 3600 * 1000;
  static const int roundedWindowMillis = 4 * 3600 * 1000;
  static const Set<Source> _loose = {
    Source.app,
    Source.screenshot,
    Source.manual,
  };

  /// Decides what to do with [tx] given nearby stored [candidates].
  DedupDecision decide(ParsedTransaction tx, List<DedupCandidate> candidates) {
    final hash = tx.transactionHash;
    final ref = _ref(tx.referenceNumber);
    final dir = tx.type.direction;

    // FR-07-02: reference + amount + direction.
    if (ref != null) {
      for (final c in candidates) {
        if (_ref(c.referenceNumber) == ref &&
            c.amountMinor == tx.amountMinor &&
            c.type.direction == dir) {
          return DedupDuplicate(c.id, DuplicateReason.reference);
        }
      }
    }

    // FR-07-03: hash, including hashes of already merged messages.
    for (final c in candidates) {
      if (c.transactionHash != hash && !c.sourceHashes.contains(hash)) {
        continue;
      }
      if (ref == null && c.sources.contains(tx.source)) {
        return DedupPossible(
          c.id,
          'Same amount, account and day, no reference number',
        );
      }
      final apart = (c.timestamp - tx.transactionTime).abs() > windowMillis;
      final dated =
          tx.source == Source.statement || c.sources.contains(Source.statement);
      final cRef = _ref(c.referenceNumber);
      if (!(apart && !dated && (ref == null || cRef == null))) {
        return DedupDuplicate(c.id, DuplicateReason.hash);
      }
      break; // hours apart with a missing reference falls through to fuzzy
    }

    // FR-07-04/05: fuzzy candidates, nearest first.
    final near = [
      for (final c in candidates)
        if (c.amountMinor == tx.amountMinor &&
            c.type.direction == dir &&
            (c.timestamp - tx.transactionTime).abs() <= statementWindowMillis)
          c,
    ]..sort(
        (a, b) => (a.timestamp - tx.transactionTime).abs().compareTo(
              (b.timestamp - tx.transactionTime).abs(),
            ),
      );
    DedupPossible? review;
    for (final c in near) {
      final gap = (c.timestamp - tx.transactionTime).abs();
      final cRef = _ref(c.referenceNumber);
      if (ref != null && cRef != null && ref != cRef) continue;
      final bothAccounts = tx.accountLast4 != null && c.accountLast4 != null;
      if (bothAccounts && !last4Match(tx.accountLast4!, c.accountLast4!)) {
        continue;
      }
      final sameAccount = bothAccounts;
      final accountless = tx.accountLast4 == null || c.accountLast4 == null;
      final sameMerchant = tx.merchant != null &&
          c.merchant != null &&
          tx.merchant!.toLowerCase() == c.merchant!.toLowerCase();
      final crossSource = !c.sources.contains(tx.source);
      final close = gap <= windowMillis;
      final loose =
          _loose.contains(tx.source) || c.sources.any(_loose.contains);
      final agree = merchantsAgree(tx.merchant, c.merchant);

      if (tx.source == Source.statement ||
          c.sources.contains(Source.statement)) {
        if (crossSource &&
            gap <= statementWindowMillis &&
            (sameAccount || accountless)) {
          return DedupDuplicate(c.id, DuplicateReason.fuzzy);
        }
        continue; // statements never raise a review
      }
      if (gap > reviewWindowMillis) continue;
      if (close && crossSource && (sameAccount || sameMerchant)) {
        return DedupDuplicate(c.id, DuplicateReason.fuzzy);
      }
      if (close && crossSource && loose && accountless && agree) {
        return DedupDuplicate(c.id, DuplicateReason.fuzzy);
      }
      if (review != null) continue;
      if (close && (sameAccount || sameMerchant)) {
        review = DedupPossible(
          c.id,
          'Same amount and ${sameAccount ? 'account' : 'merchant'} '
          'within 30 minutes',
        );
      } else if (close && crossSource && (!loose || agree)) {
        review = DedupPossible(
          c.id,
          'Same amount from SMS and email within 30 minutes',
        );
      } else if (crossSource && sameAccount) {
        review = DedupPossible(
          c.id,
          'Same amount and account on the same day, from SMS and email',
        );
      }
    }

    // FR-07-06: payment-app amounts rounded to whole rupees.
    final rounded = _rounded(tx, candidates, ref);
    if (rounded != null) return DedupDuplicate(rounded, DuplicateReason.fuzzy);

    return review ?? const DedupNew();
  }

  int? _rounded(ParsedTransaction tx, List<DedupCandidate> cs, String? ref) {
    final incomingApp = tx.source == Source.app;
    final whole = tx.amountMinor % 100 == 0;
    if (incomingApp && !whole) return null;
    if (!incomingApp && whole) return null;
    DedupCandidate? best;
    var bestGap = 1 << 62;
    for (final c in cs) {
      final amountOk = incomingApp
          ? c.amountMinor > tx.amountMinor &&
              c.amountMinor <= tx.amountMinor + 99
          : c.amountMinor == tx.amountMinor - tx.amountMinor % 100;
      if (!amountOk || c.type.direction != tx.type.direction) continue;
      final gap = (c.timestamp - tx.transactionTime).abs();
      if (gap > statementWindowMillis) continue;
      if (c.sources.contains(tx.source)) continue;
      final shape = incomingApp
          ? c.sources.any((s) => s != Source.app)
          : c.sources.every((s) => s == Source.app);
      if (!shape) continue;
      if (!(_istDay(c.timestamp) == _istDay(tx.transactionTime) ||
          gap <= roundedWindowMillis)) {
        continue;
      }
      if (tx.accountLast4 != null &&
          c.accountLast4 != null &&
          !last4Match(tx.accountLast4!, c.accountLast4!)) {
        continue;
      }
      final cRef = _ref(c.referenceNumber);
      if (ref != null && cRef != null && ref != cRef) continue;
      if (!merchantsAgree(tx.merchant, c.merchant)) continue;
      if (gap < bestGap) {
        best = c;
        bestGap = gap;
      }
    }
    return best?.id;
  }

  static int _istDay(int ms) => (ms + 19800000) ~/ 86400000;

  static String? _ref(String? r) => (r == null || r.isEmpty) ? null : r;

  /// Equal, or one ends with the other ("123" vs "0123").
  static bool last4Match(String a, String b) => a.endsWith(b) || b.endsWith(a);

  static const _generic = {
    'payment',
    'upi payment',
    'paid',
    'transaction',
    'money sent',
    'money received',
    'bank transfer',
    'upi',
    'transfer',
  };

  /// True when either side is null/generic, one contains the other (compared
  /// as lower-case alphanumerics) or they share a word of 3+ letters.
  static bool merchantsAgree(String? a, String? b) {
    if (a == null || b == null) return true;
    if (_generic.contains(a.trim().toLowerCase()) ||
        _generic.contains(b.trim().toLowerCase())) {
      return true;
    }
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final na = norm(a);
    final nb = norm(b);
    if (na.isNotEmpty &&
        nb.isNotEmpty &&
        (na.contains(nb) || nb.contains(na))) {
      return true;
    }
    Set<String> words(String s) => RegExp('[a-z]{3,}')
        .allMatches(s.toLowerCase())
        .map((m) => m[0]!)
        .toSet();
    return words(a).intersection(words(b)).isNotEmpty;
  }
}

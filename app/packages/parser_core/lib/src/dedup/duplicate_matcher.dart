import 'package:parser_core/src/dedup/dedup_models.dart';
import 'package:parser_core/src/extract/generic_phrases.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// Decides whether a parsed message duplicates a stored transaction, in the
/// order the spec fixes (FR-07-02 to FR-07-06):
/// 1. same reference number (and amount, direction);
/// 2. same transactionHash (from the same source without a reference, only a
///    possible duplicate);
/// 3. fuzzy: same amount and direction, and same account or same merchant,
///    within +-30 minutes.
///
/// Fuzzy matches merge automatically only across sources (an SMS and an
/// email). Two SMS for the same amount on the same card within half an hour can
/// be two real purchases, so those go to review. A cross-source match on the
/// same account later the same day is also sent to review, which covers a bank
/// email that arrives hours late.
abstract final class DuplicateMatcher {
  /// Close in time: 30 minutes.
  static const int windowMillis = 30 * 60 * 1000;

  /// Review window: 12 hours.
  static const int reviewWindowMillis = 12 * 60 * 60 * 1000;

  /// A statement row carries only a date: 36 hours.
  static const int statementWindowMillis = 36 * 60 * 60 * 1000;

  /// Rounded payment-app amounts: 4 hours.
  static const int roundedWindowMillis = 4 * 60 * 60 * 1000;

  static const _looseSources = {'APP', 'SCREENSHOT', 'MANUAL'};
  static const _statement = 'STATEMENT';

  /// The verdict for [tx] against what [lookup] holds. [utcOffset] is the zone
  /// that defines "the same day" (IST by default).
  static Future<DedupDecision> decide(
    ParsedTransaction tx,
    DedupLookup lookup, {
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) async {
    final txSource = sourceKey(tx.source);
    final ref = tx.referenceNumber;
    if (ref != null) {
      for (final s in await lookup.byReference(ref)) {
        if (s.amountMinor == tx.amountMinor &&
            s.type.direction == tx.type.direction) {
          return Duplicate(s.id, MatchReason.reference);
        }
      }
    }
    final h = await lookup.byHash(tx.transactionHash);
    if (h != null) {
      // Without a reference the hash is only amount + account + day, so two
      // purchases of the same amount on one card in a day collide. Across
      // sources that is the same transaction; from the same source it may be
      // two, so the user decides. (Re-reading one message never gets here: the
      // source message id is checked first.)
      if (tx.referenceNumber == null && h.sources.contains(txSource)) {
        return PossibleDuplicate(
          h.id,
          'Same amount, account and day, no reference number',
        );
      }
      // Hours apart with no shared reference they are two purchases (a 9am and
      // an 8pm order of the same amount on one card); the fuzzy rules below
      // decide, sending it to review when unsure.
      final apart =
          (h.transactionTime - tx.transactionTime).abs() > windowMillis;
      final dated = txSource == _statement || h.sources.contains(_statement);
      if (!(apart &&
          !dated &&
          (tx.referenceNumber == null || h.referenceNumber == null))) {
        return Duplicate(h.id, MatchReason.hash);
      }
    }

    final found = await lookup.potentialDuplicates(
      tx.amountMinor,
      tx.transactionTime - statementWindowMillis,
      tx.transactionTime + statementWindowMillis,
    );
    // A stable sort by distance in time.
    final indexed = [
      for (var i = 0; i < found.length; i++)
        if (found[i].type.direction == tx.type.direction) (i, found[i]),
    ]..sort((a, b) {
        final da = (a.$2.transactionTime - tx.transactionTime).abs();
        final db = (b.$2.transactionTime - tx.transactionTime).abs();
        return da != db ? da.compareTo(db) : a.$1.compareTo(b.$1);
      });
    final candidates = [for (final e in indexed) e.$2];

    (StoredTransaction, String)? review;
    for (final c in candidates) {
      // Two different references are two different transactions, however alike
      // they look.
      if (c.referenceNumber != null &&
          tx.referenceNumber != null &&
          c.referenceNumber != tx.referenceNumber) {
        continue;
      }
      final cLast4 = c.accountLast4;
      final tLast4 = tx.accountLast4;
      final bothHaveAccount = cLast4 != null && tLast4 != null;
      final sameAccount = bothHaveAccount && last4Match(cLast4, tLast4);
      if (bothHaveAccount && !sameAccount) continue;

      final sameMerchant = c.merchant != null &&
          tx.merchant != null &&
          c.merchant!.toLowerCase() == tx.merchant!.toLowerCase();
      final crossSource = !c.sources.contains(txSource);
      final gap = (c.transactionTime - tx.transactionTime).abs();
      final close = gap <= windowMillis;

      // A payment-app notification, a screenshot or a typed entry rarely names
      // the account; when it meets a bank message for the same amount within
      // the window, it is the same payment.
      final loose = _looseSources.contains(txSource) ||
          c.sources.any(_looseSources.contains);
      final accountless = cLast4 == null || tLast4 == null;

      // A statement row has only a date (stored at noon), so it matches the SMS
      // or email for the same amount and account within a day and a half either
      // side.
      final statement =
          txSource == _statement || c.sources.contains(_statement);
      if (statement) {
        if (crossSource &&
            gap <= statementWindowMillis &&
            (sameAccount || accountless)) {
          return Duplicate(c.id, MatchReason.fuzzy);
        }
        continue;
      }
      if (gap > reviewWindowMillis) continue;

      if (close && crossSource && (sameAccount || sameMerchant)) {
        return Duplicate(c.id, MatchReason.fuzzy);
      }
      // Same amount to a different payee a few minutes apart is another
      // payment, not this one.
      if (close &&
          crossSource &&
          loose &&
          accountless &&
          merchantsAgree(c.merchant, tx.merchant)) {
        return Duplicate(c.id, MatchReason.fuzzy);
      }
      if (review != null) continue;
      if (close && (sameAccount || sameMerchant)) {
        review = (
          c,
          'Same amount and ${sameAccount ? 'account' : 'merchant'} within 30 minutes',
        );
      } else if (close &&
          crossSource &&
          (!loose || merchantsAgree(c.merchant, tx.merchant))) {
        review = (c, 'Same amount from SMS and email within 30 minutes');
      } else if (crossSource && sameAccount) {
        review =
            (c, 'Same amount and account on the same day, from SMS and email');
      }
    }
    final rounded = await _roundedAppMatch(tx, lookup, utcOffset);
    if (rounded != null) return Duplicate(rounded.id, MatchReason.fuzzy);
    if (review != null) return PossibleDuplicate(review.$1.id, review.$2);
    return const NewTransaction();
  }

  /// A payment-app notification often shows a rounded amount ("Rs 144") where
  /// the bank message has paise ("144.93"), and carries no reliable time. It
  /// matches a bank/email/statement record of the same direction when the
  /// amounts agree after dropping paise, it is the same day (or within 4
  /// hours), and the merchants do not conflict. Nothing else is loosened.
  static Future<StoredTransaction?> _roundedAppMatch(
    ParsedTransaction tx,
    DedupLookup lookup,
    Duration utcOffset,
  ) async {
    final txSource = sourceKey(tx.source);
    final incomingApp = txSource == 'APP';
    final whole = tx.amountMinor % 100 == 0;
    final int lo;
    final int hi;
    if (incomingApp && whole) {
      lo = tx.amountMinor + 1;
      hi = tx.amountMinor + 99;
    } else if (!incomingApp && !whole) {
      lo = tx.amountMinor - tx.amountMinor % 100;
      hi = lo;
    } else {
      return null;
    }
    final from = tx.transactionTime - statementWindowMillis;
    final to = tx.transactionTime + statementWindowMillis;
    final day = civilDateOf(tx.transactionTime, utcOffset);
    final rows = await lookup.potentialDuplicatesInRange(lo, hi, from, to);
    StoredTransaction? best;
    var bestGap = 0;
    for (final c in rows) {
      if (c.type.direction != tx.type.direction) continue;
      if (c.sources.contains(txSource)) continue;
      final sourcesOk = incomingApp
          ? c.sources.any((s) => s != 'APP')
          : c.sources.every((s) => s == 'APP');
      if (!sourcesOk) continue;
      final gap = (c.transactionTime - tx.transactionTime).abs();
      final sameDay = civilDateOf(c.transactionTime, utcOffset) == day;
      if (!(sameDay || gap <= roundedWindowMillis)) continue;
      final cLast4 = c.accountLast4;
      final tLast4 = tx.accountLast4;
      final accountOk =
          cLast4 == null || tLast4 == null || last4Match(cLast4, tLast4);
      final refOk = c.referenceNumber == null ||
          tx.referenceNumber == null ||
          c.referenceNumber == tx.referenceNumber;
      if (!(accountOk && refOk && merchantsAgree(c.merchant, tx.merchant))) {
        continue;
      }
      if (best == null || gap < bestGap) {
        best = c;
        bestGap = gap;
      }
    }
    return best;
  }

  static final _nonAlnum = RegExp('[^a-z0-9]+');

  static Set<String> _words(String s) =>
      s.toLowerCase().split(_nonAlnum).where((w) => w.length >= 3).toSet();

  /// True unless both name a real merchant and the names differ (one containing
  /// the other counts as the same).
  static bool merchantsAgree(String? a, String? b) {
    if (a == null ||
        b == null ||
        GenericPhrases.isGeneric(a) ||
        GenericPhrases.isGeneric(b)) {
      return true;
    }
    final x = lettersAndDigits(a.toLowerCase());
    final y = lettersAndDigits(b.toLowerCase());
    if (x.isEmpty || y.isEmpty || x.contains(y) || y.contains(x)) return true;
    // "Ravi Kumar" and "R Kumar" share a name part.
    return _words(a).intersection(_words(b)).isNotEmpty;
  }

  /// "123" (ICICI prints 3 digits) matches "0123".
  static bool last4Match(String a, String b) =>
      a == b || a.endsWith(b) || b.endsWith(a);
}

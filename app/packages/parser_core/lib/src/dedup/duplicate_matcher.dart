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

  /// A shared reference merges within 3 days (a statement's value date can
  /// differ from the posting by more): 72 hours, 96 with a statement.
  static const int referenceWindowMillis = 72 * 60 * 60 * 1000;

  /// See [referenceWindowMillis].
  static const int referenceStatementWindowMillis = 96 * 60 * 60 * 1000;

  /// The same payment announced by two different payment apps: 10 minutes.
  static const int crossAppWindowMillis = 10 * 60 * 1000;

  /// Late mail for an SMS the day before: 24 hours.
  static const int lateMailWindowMillis = 24 * 60 * 60 * 1000;

  /// Two messages that print times this far apart are two transactions.
  static const int explicitTimeApartMillis = 60 * 1000;

  /// One payment can be announced twice by payment apps (a status, then a
  /// receipt) within seconds; further apart it is another payment: 2 minutes.
  static const int appRepostWindowMillis = 2 * 60 * 1000;

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
    final txIsApp = txSource == 'APP';
    final ref = tx.referenceNumber;
    if (ref != null) {
      PossibleDuplicate? sameRef;
      for (final s in await lookup.byReference(ref)) {
        if (!refsEqual(s.referenceNumber, ref)) continue;
        // The same reference on money going the other way is a reversal or a
        // refund, never the same transaction (FR-07-19).
        if (s.type.direction != tx.type.direction) continue;
        if (!(s.amountMinor == tx.amountMinor || _roundedRelation(s, tx))) {
          continue;
        }
        final statement =
            txSource == _statement || s.sources.contains(_statement);
        final limit =
            statement ? referenceStatementWindowMillis : referenceWindowMillis;
        final gap = (s.transactionTime - tx.transactionTime).abs();
        final sLast4 = s.accountLast4;
        final tLast4 = tx.accountLast4;
        final conflict =
            sLast4 != null && tLast4 != null && !last4Match(sLast4, tLast4);
        if (gap <= limit && !conflict) {
          return Duplicate(s.id, MatchReason.reference);
        }
        sameRef ??= PossibleDuplicate(
          s.id,
          conflict
              ? 'Same reference on different accounts'
              : 'Same reference, ${(gap / Duration.millisecondsPerDay).round()} days apart',
        );
      }
      if (sameRef != null) return sameRef;
    }
    var h = await lookup.byHash(tx.transactionHash);
    if (h != null) {
      // Two rows that state a balance say whether they are one transaction or
      // two (FR-07-21), whatever their hash says.
      switch (_balanceVerdict(h, tx)) {
        case _Balance.same:
          return Duplicate(h.id, MatchReason.hash);
        case _Balance.sequential:
          h = null;
        case _Balance.unknown:
          break;
      }
    }
    // Two messages from one source that print different times, with no
    // reference to say otherwise, are two transactions: two ₹20 teas minutes
    // apart (FR-07-21).
    if (h != null &&
        tx.referenceNumber == null &&
        h.sources.contains(txSource) &&
        _timesDiffer(h, tx)) {
      h = null;
    }
    if (h != null && txIsApp && ref == null && h.sources.contains('APP')) {
      // A payment-app notification names no account and usually no reference,
      // so its hash is only amount, direction and day: two ₹50 payments in a
      // day, to different people, share it. Between two notifications only a
      // re-post within seconds is the same payment; the scan below still
      // matches it against a bank message.
      if (_appRepost(h, tx)) return Duplicate(h.id, MatchReason.hash);
    } else if (h != null) {
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
          !refsEqual(c.referenceNumber, tx.referenceNumber)) {
        continue;
      }
      final cLast4 = c.accountLast4;
      final tLast4 = tx.accountLast4;
      final bothHaveAccount = cLast4 != null && tLast4 != null;
      final sameAccount = bothHaveAccount && last4Match(cLast4, tLast4);
      if (bothHaveAccount && !sameAccount) continue;

      // Stated balances settle it: equal is one transaction, a step of exactly
      // the amount is two (FR-07-21).
      switch (_balanceVerdict(c, tx)) {
        case _Balance.same:
          return Duplicate(c.id, MatchReason.fuzzy);
        case _Balance.sequential:
          continue;
        case _Balance.unknown:
          break;
      }

      // Two messages from one source printing different times, with no
      // reference to say otherwise, are two transactions (FR-07-21).
      if (tx.referenceNumber == null &&
          c.sources.contains(txSource) &&
          _timesDiffer(c, tx)) {
        continue;
      }

      // The same payment announced by two different payment apps (a bank app
      // and Google Pay) is one payment: another channel, not a repeat
      // (FR-07-20).
      if (txIsApp &&
          c.sources.contains('APP') &&
          c.appSenders.isNotEmpty &&
          !c.appSenders.contains(tx.sender.toLowerCase())) {
        if ((c.transactionTime - tx.transactionTime).abs() <=
                crossAppWindowMillis &&
            merchantsAgree(c.merchant, tx.merchant)) {
          return Duplicate(c.id, MatchReason.fuzzy);
        }
        continue;
      }

      // Two payment-app notifications for one amount are two payments unless
      // the second is a re-post within seconds. The same payee within half an
      // hour is left to the user; anything else is simply another payment.
      if (txIsApp && c.sources.contains('APP')) {
        if (_appRepost(c, tx)) return Duplicate(c.id, MatchReason.fuzzy);
        if (review == null &&
            (c.transactionTime - tx.transactionTime).abs() <= windowMillis &&
            _samePayee(c.merchant, tx.merchant)) {
          review = (c, 'Same amount and merchant within 30 minutes');
        }
        continue;
      }

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
      if (gap > reviewWindowMillis) {
        // An email for an SMS the day before: worth a look, never a silent
        // merge (FR-07-22).
        if (review == null &&
            gap <= lateMailWindowMillis &&
            crossSource &&
            (sameAccount || (accountless && tx.type.direction == 'IN')) &&
            _mailAgainstMessage(c, tx) &&
            _namedPayeesAgree(c.merchant, tx.merchant)) {
          review = (c, 'Same amount from SMS and email on consecutive days');
        }
        continue;
      }

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
      } else if (crossSource &&
          accountless &&
          tx.type.direction == 'IN' &&
          !loose &&
          !_timesDiffer(c, tx) &&
          civilDateOf(c.transactionTime, utcOffset) ==
              civilDateOf(tx.transactionTime, utcOffset) &&
          (c.merchant == null ||
              tx.merchant == null ||
              merchantsAgree(c.merchant, tx.merchant))) {
        // Income often arrives as an SMS and an email, one without the
        // account digits: same amount, same day, no conflicting payee or
        // printed time. Worth asking, never a silent second row (FR-07-23).
        review = (c, 'Same income amount and day, from SMS and email');
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

  /// An email on one side, an SMS or notification on the other.
  static bool _mailAgainstMessage(StoredTransaction c, ParsedTransaction tx) {
    final txMail = sourceKey(tx.source) == 'EMAIL';
    final cMail = c.sources.contains('EMAIL');
    final cOther = c.sources.contains('SMS') || c.sources.contains('APP');
    final txOther =
        sourceKey(tx.source) == 'SMS' || sourceKey(tx.source) == 'APP';
    return (txMail && cOther && !cMail) || (txOther && cMail && !cOther);
  }

  /// Both name a real payee and they agree.
  static bool _namedPayeesAgree(String? a, String? b) => _samePayee(a, b);

  /// Both messages print a time of day and the times are a minute or more
  /// apart.
  static bool _timesDiffer(StoredTransaction c, ParsedTransaction tx) =>
      c.hasExplicitTime &&
      tx.hasExplicitTime &&
      (c.transactionTime - tx.transactionTime).abs() >= explicitTimeApartMillis;

  /// What two stated balances say about two rows of the same amount and
  /// direction on the same account.
  static _Balance _balanceVerdict(StoredTransaction c, ParsedTransaction tx) {
    final cb = c.balanceMinor;
    final tb = tx.balanceMinor;
    if (cb == null || tb == null) return _Balance.unknown;
    if (c.amountMinor != tx.amountMinor ||
        c.type.direction != tx.type.direction) {
      return _Balance.unknown;
    }
    final cl = c.accountLast4;
    final tl = tx.accountLast4;
    if (cl == null || tl == null || !last4Match(cl, tl)) {
      return _Balance.unknown;
    }
    if (cb == tb) {
      // The same balance a day apart is one message told twice.
      return (c.transactionTime - tx.transactionTime).abs() <=
              lateMailWindowMillis
          ? _Balance.same
          : _Balance.unknown;
    }
    final earlier = c.transactionTime <= tx.transactionTime;
    final eb = earlier ? cb : tb;
    final lb = earlier ? tb : cb;
    final step = tx.type.direction == 'OUT' ? -c.amountMinor : c.amountMinor;
    return lb == eb + step ? _Balance.sequential : _Balance.unknown;
  }

  /// A payment-app amount of whole rupees against a bank amount with paise.
  static bool _roundedRelation(StoredTransaction c, ParsedTransaction tx) {
    final d = c.amountMinor - tx.amountMinor;
    final txApp = sourceKey(tx.source) == 'APP';
    final cApp = c.sources.length == 1 && c.sources.contains('APP');
    if (txApp && tx.amountMinor % 100 == 0) return d >= 1 && d <= 99;
    if (cApp && c.amountMinor % 100 == 0) return -d >= 1 && -d <= 99;
    return false;
  }

  static final RegExp _refKeep = RegExp('[^A-Z0-9]');

  /// A reference as compared: upper-case letters and digits, leading zeros
  /// dropped. Null when too short (under 6) or one repeated character to say
  /// anything (FR-07-19).
  static String? normalizeReference(String? r) {
    if (r == null) return null;
    final t = r
        .toUpperCase()
        .replaceAll(_refKeep, '')
        .replaceFirst(RegExp('^0+'), '');
    if (t.length < 6) return null;
    if (t.split('').toSet().length == 1) return null;
    return t;
  }

  /// Two references name one payment: equal once normalised, or one is a
  /// 12-digit UPI/IMPS reference and the other the same digits with a short
  /// prefix (`UPI612345678901`) (FR-07-19).
  static bool refsEqual(String? a, String? b) {
    final x = normalizeReference(a);
    final y = normalizeReference(b);
    if (x == null || y == null) return a == b;
    if (x == y) return true;
    bool rrn(String v) => RegExp(r'^\d{12}$').hasMatch(v);
    if (rrn(x) && y.length <= 22 && y.endsWith(x)) return true;
    if (rrn(y) && x.length <= 22 && x.endsWith(y)) return true;
    return false;
  }

  /// A second notification for the same payment: seconds apart and not naming
  /// a different payee.
  static bool _appRepost(StoredTransaction c, ParsedTransaction tx) =>
      (c.transactionTime - tx.transactionTime).abs() <= appRepostWindowMillis &&
      merchantsAgree(c.merchant, tx.merchant);

  /// Both name a real payee and it is the same one.
  static bool _samePayee(String? a, String? b) =>
      a != null &&
      b != null &&
      !GenericPhrases.isGeneric(a) &&
      !GenericPhrases.isGeneric(b) &&
      merchantsAgree(a, b);

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

/// What stated balances say about two rows.
enum _Balance { same, sequential, unknown }

import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// A masked account or card number reduced to its last digits.
class AccountRef {
  /// Creates a reference.
  const AccountRef(this.last4, this.kind);

  /// Last digits (usually four; some issuers print two or three).
  final String last4;

  /// Account or card.
  final AccountKind kind;

  @override
  bool operator ==(Object other) =>
      other is AccountRef && other.last4 == last4 && other.kind == kind;

  @override
  int get hashCode => Object.hash(last4, kind);

  @override
  String toString() => 'AccountRef($last4, $kind)';
}

class _Candidate {
  _Candidate(
    this.start,
    this.digitsStart,
    this.digitsEnd,
    this.last4,
    this.kind, {
    required this.labelled,
  });
  final int start;
  final int digitsStart;
  final int digitsEnd; // exclusive
  final String last4;
  final AccountKind kind;
  final bool labelled;
}

/// Pulls the masked account or card number ("A/c XX1234", "Card ending 5678",
/// "4xxx xxxx xxxx 9012") (FR-06-07).
abstract final class AccountExtractor {
  static final RegExp _labelled = rx(
    r'(?:\b(a/c|ac|acct|account)|(card))(?:\s*(?:no|number|num)\.?)?(?:\s*(?:ending|ends)(?:\s+(?:with|in))?)?'
    r'\s*[:.\-]?\s*(?:\d{0,6}[x*#.][x*#.\s]*)?(\d{3,6})\b',
  );
  static final RegExp _masked = rx(r'(?<![\w*])[x*]{2,}(\d{3,4})\b');
  static final RegExp _cardWord = rx(r'\bcard\b');

  /// Some issuers print only two digits: "SBI Corporate Card number ending
  /// with 96".
  static final RegExp _shortEnding = rx(
    r'\b(card|a/c|ac|acct|account)(?:\s*(?:no|number|num)\.?)?\s+(?:ending|ends)(?:\s+(?:with|in))?\s*[x*]*(\d{2})\b',
  );

  /// Words before the other party's number: "to A/c XX5678", "from A/c" on a
  /// credit.
  static final RegExp _toBefore =
      rx(r"\bto\s+(?:the\s+)?(?:(?!from\b)[\w'’]+\s+){0,2}$");
  static final RegExp _payerBefore = rx(
    r"\b(?:from|by|remitter|sender)\s+(?:the\s+)?(?:[\w'’]+\s+){0,2}$",
  );

  /// Always the other party, whatever the direction: "Beneficiary A/c XX9876",
  /// "in favour of a/c".
  static final RegExp _beneficiaryBefore = rx(
    r"\b(?:benef\w*|bene|payee|recipient|in\s+favou?r\s+of)\s*[:\-]?\s*(?:the\s+)?(?:[\w'’]+\s+){0,2}$",
  );
  static final RegExp _your = rx(r'\b(?:your|ur|own|self)\b');

  /// A masked number right after these words is the user's phone or UPI ID,
  /// not an account.
  static final RegExp _phoneBefore = rx(
    r'(?:\b(?:mobile|mob|phone|ph|cell|cellphone|contact|call|whatsapp|registered|upi\s+id|vpa|(?:sms|msg)\s+to)\b'
    r'[\s:.\-#]*(?:(?:no|number|num|is|linked|of|with)\b[\s:.\-#]*){0,3}|\+91[\s\-]?|\b91-)$',
  );

  /// "XXXXXX6810@ybl", "9876546810@axl": the digits are part of a UPI ID.
  static final RegExp _vpaAfter = rx(r'^[\w.\-]*@[a-z]');

  static const _window = 30;

  /// The user's account. A number inside a UPI ID or written as a phone number
  /// is never taken, nor one labelled as the beneficiary's. With [type], a
  /// number written as the other party's ("sent to A/c XX5678", "received from
  /// A/c XX9999") is skipped too, so a payee never shows up as the user's
  /// account; if the only number in the message is the other party's, the
  /// result is null.
  static AccountRef? extract(String text, [TransactionType? type]) {
    for (final c in _candidates(text)) {
      if (_isPhoneOrVpa(text, c) || _isOtherParty(text, c, type)) continue;
      return AccountRef(c.last4, c.kind);
    }
    return null;
  }

  /// Labelled numbers first, then bare masked ones, then two-digit endings;
  /// each number once.
  static List<_Candidate> _candidates(String text) {
    final out = <_Candidate>[];
    final seen = <(int, int)>[];
    bool fresh(int s, int e) {
      // ranges are [s, e); the Kotlin check is on inclusive ranges.
      final overlaps = seen.any((r) => r.$1 < e && s < r.$2);
      if (!overlaps) seen.add((s, e));
      return !overlaps;
    }

    for (final m in _labelled.allMatches(text)) {
      final g = grp(m, 3);
      final gs = m.end - g.length;
      if (!fresh(gs, m.end)) continue;
      final before =
          text.substring(m.start - 15 < 0 ? 0 : m.start - 15, m.start);
      final isCard = m.group(2) != null || _cardWord.hasMatch(before);
      out.add(
        _Candidate(
          m.start,
          gs,
          m.end,
          takeLast(g, 4),
          isCard ? AccountKind.card : AccountKind.account,
          labelled: true,
        ),
      );
    }
    final masked = _masked.allMatches(text).toList();
    if (masked.isNotEmpty) {
      final kind =
          _cardWord.hasMatch(text) ? AccountKind.card : AccountKind.account;
      for (final m in masked) {
        final g = grp(m, 1);
        final gs = m.end - g.length;
        if (!fresh(gs, m.end)) continue;
        out.add(_Candidate(m.start, gs, m.end, g, kind, labelled: false));
      }
    }
    for (final m in _shortEnding.allMatches(text)) {
      final g = grp(m, 2);
      final gs = m.end - g.length;
      if (!fresh(gs, m.end)) continue;
      final kind = grp(m, 1).toLowerCase() == 'card'
          ? AccountKind.card
          : AccountKind.account;
      out.add(_Candidate(m.start, gs, m.end, g, kind, labelled: true));
    }
    return out;
  }

  static bool _isPhoneOrVpa(String text, _Candidate c) {
    final end = c.digitsEnd + 39 > text.length ? text.length : c.digitsEnd + 39;
    final after = text.substring(c.digitsEnd, end);
    if (_vpaAfter.hasMatch(after)) return true;
    // A label ("A/c", "Card") says it is an account; only a bare masked number
    // can be a phone.
    if (c.labelled) return false;
    final from = c.start - _window < 0 ? 0 : c.start - _window;
    return _phoneBefore.hasMatch(text.substring(from, c.start));
  }

  static bool _isOtherParty(String text, _Candidate c, TransactionType? type) {
    final from = c.start - _window < 0 ? 0 : c.start - _window;
    final before = text.substring(from, c.start);
    if (_counterparty(_beneficiaryBefore, before)) return true;
    final RegExp other;
    switch (type) {
      case null:
        return false;
      case TransactionType.credit:
        other = _payerBefore;
      case TransactionType.debit ||
            TransactionType.transfer ||
            TransactionType.investment:
        other = _toBefore;
    }
    return _counterparty(other, before);
  }

  /// The cue word matches and is not qualified as the user's own ("to your A/c"
  /// is the user's).
  static bool _counterparty(RegExp cue, String before) {
    final m = findFrom(cue, before);
    if (m == null) return false;
    return !_your.hasMatch(m.group(0)!);
  }

  /// Kind of the first account in [text]; an account when none.
  static AccountKind kindOf(String text) =>
      extract(text)?.kind ?? AccountKind.account;
}

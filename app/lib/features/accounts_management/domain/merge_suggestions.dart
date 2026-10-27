import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:parser_core/parser_core.dart';

/// "Possible duplicate": merge [source] into [target] (FR-13-09).
class MergeSuggestion {
  /// Creates a suggestion.
  const MergeSuggestion(this.source, this.target);

  final Account source;
  final Account target;

  /// Dismissal key for the session.
  String get key => '${source.id}>${target.id}';
}

/// "Link this debit card?" (FR-13-09).
class LinkSuggestion {
  /// Creates a suggestion.
  const LinkSuggestion(this.card, this.account, this.reason);

  final Account card;
  final Account account;
  final String reason;
}

bool _odd(String s) => s.length < 2 || s.length > 4 || int.tryParse(s) == null;

/// Either number is odd, or the last `min(len)` digits are equal.
bool sameNumber(String a, String b) {
  if (_odd(a) || _odd(b)) return true;
  final n = a.length < b.length ? a.length : b.length;
  return a.substring(a.length - n) == b.substring(b.length - n);
}

/// Duplicate suggestions among visible [accounts] (memory 13 section 3.4).
/// [counts] maps account id to its transaction count.
List<MergeSuggestion> duplicateSuggestions(
  List<Account> accounts,
  Map<int, int> counts,
) {
  final groups = <String, List<Account>>{};
  for (final a in accounts.where((a) => !a.hidden && a.mergedIntoId == null)) {
    (groups['${a.bankName.trim().toLowerCase()}|${a.kind.name}'] ??= []).add(a);
  }
  final out = <MergeSuggestion>[];
  final used = <int>{};
  for (final g in groups.values) {
    for (var i = 0; i < g.length; i++) {
      for (var j = i + 1; j < g.length; j++) {
        final a = g[i];
        final b = g[j];
        if (used.contains(a.id) || used.contains(b.id)) continue;
        if (a.accountType != null &&
            b.accountType != null &&
            a.accountType != b.accountType) {
          continue;
        }
        if (!sameNumber(a.last4, b.last4)) continue;
        // Target: a proper number first, then more transactions.
        final aOdd = _odd(a.last4);
        final bOdd = _odd(b.last4);
        final aTarget =
            aOdd != bOdd ? !aOdd : (counts[a.id] ?? 0) >= (counts[b.id] ?? 0);
        final target = aTarget ? a : b;
        final source = aTarget ? b : a;
        used.add(source.id);
        out.add(MergeSuggestion(source, target));
      }
    }
  }
  return out;
}

/// Debit-card link suggestions (memory 13 section 3.4).
List<LinkSuggestion> linkSuggestions(
  List<Account> accounts,
  Map<int, int> counts,
) {
  final visible =
      accounts.where((a) => !a.hidden && a.mergedIntoId == null).toList();
  final out = <LinkSuggestion>[];
  for (final c in visible) {
    if (c.kind != AccountKind.card || c.linkedAccountId != null) continue;
    final debit = c.isDebitCard ||
        (c.accountType == null && c.latestBalanceMinor != null);
    if (!debit) continue;
    final cands = [
      for (final a in visible)
        if (a.isLiquid && a.bankName == c.bankName) a,
    ];
    if (cands.isEmpty) continue;
    final byBalance = c.latestBalanceMinor == null
        ? null
        : cands
            .where((a) => a.latestBalanceMinor == c.latestBalanceMinor)
            .firstOrNull;
    if (byBalance != null) {
      out.add(
        LinkSuggestion(
          c,
          byBalance,
          "The balance in this card's SMS matches this account.",
        ),
      );
    } else if (cands.length == 1) {
      out.add(
        LinkSuggestion(
          c,
          cands.single,
          "It's your only ${c.bankName} account.",
        ),
      );
    } else {
      final best = ([...cands]..sort(
              (x, y) => (counts[y.id] ?? 0).compareTo(counts[x.id] ?? 0),
            ))
          .first;
      out.add(
        LinkSuggestion(c, best, 'Your most used ${c.bankName} account.'),
      );
    }
  }
  return out;
}

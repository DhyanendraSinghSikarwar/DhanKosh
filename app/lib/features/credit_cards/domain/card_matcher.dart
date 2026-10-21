import 'package:hisaab/features/credit_cards/domain/card_models.dart';

/// A credit card account as far as row matching is concerned.
class CardRef {
  /// Creates a reference.
  const CardRef({required this.id, required this.bankName, required this.last4});

  final int id;
  final String bankName;
  final String last4;
}

/// Issuer and card matching (FR-14-06, memory 14 section 3.3).
abstract final class CardMatcher {
  static final _keys = <String, RegExp>{
    'hdfc': RegExp(r'\bhdfc\b'),
    'icici': RegExp(r'\bicici\b'),
    'axis': RegExp(r'\baxis\b'),
    'hsbc': RegExp(r'\bhsbc\b'),
    'sbi': RegExp(r'\bsbi\b|state bank'),
    'kotak': RegExp(r'\bkotak\b'),
    'yes': RegExp(r'\byes\b'),
    'idfc': RegExp(r'\bidfc\b'),
    'indusind': RegExp(r'\bindusind\b'),
    'baroda': RegExp(r'\bbaroda\b'),
    'pnb': RegExp(r'\bpnb\b|punjab national'),
    'federal': RegExp(r'\bfederal\b'),
    'canara': RegExp(r'\bcanara\b'),
    'union': RegExp(r'\bunion\b'),
    'rbl': RegExp(r'\brbl\b'),
    'scb': RegExp(r'\bscb\b|standard chartered'),
    'amex': RegExp(r'\bamex\b|american express'),
    'au': RegExp(r'\bau\b'),
  };

  /// Canonical issuer key (`hdfc`, `axis`, ...) or the noise-stripped name.
  static String issuerKey(String name) {
    final lower = name.toLowerCase();
    for (final e in _keys.entries) {
      if (e.value.hasMatch(lower)) return e.key;
    }
    return lower
        .replaceAll(RegExp(r'\b(bank|credit|card|cards|ltd|limited)\b'), ' ')
        .replaceAll(RegExp('[^a-z0-9]'), '');
  }

  /// Same issuer: equal keys, or one a prefix of the other (min length 3).
  static bool bankMatches(String? a, String? b) {
    if (a == null || b == null) return false;
    final x = issuerKey(a);
    final y = issuerKey(b);
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    return x.length >= 3 && y.length >= 3 && (x.startsWith(y) || y.startsWith(x));
  }

  /// Key under which a card's override is stored: `<bank lower>:<last4>`.
  static String cardKey(String bankName, String last4) =>
      '${bankName.toLowerCase()}:$last4';

  /// Rows that belong to [card] among [cards] (all known credit cards).
  static List<CardRow> rowsFor(
    CardRef card,
    List<CardRef> cards,
    List<CardRow> rows,
  ) {
    final sameIssuer = cards.where((c) => bankMatches(c.bankName, card.bankName));
    final only = sameIssuer.length == 1;
    final knownLast4 = {for (final c in cards) c.last4};
    return [
      for (final r in rows)
        if (_matches(r, card, only, knownLast4)) r,
    ];
  }

  static bool _matches(CardRow r, CardRef card, bool only, Set<String> known) {
    final l4 = r.last4;
    if (l4 != null && l4.isNotEmpty && l4 == card.last4) {
      return r.bankName == null || bankMatches(r.bankName, card.bankName);
    }
    if (only &&
        r.bankName != null &&
        bankMatches(r.bankName, card.bankName) &&
        (l4 == null || l4.isEmpty || !known.contains(l4))) {
      return true;
    }
    return false;
  }
}

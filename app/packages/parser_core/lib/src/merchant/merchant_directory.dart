import 'package:parser_core/src/merchant/merchant_data.dart';
import 'package:parser_core/src/model/model.dart';

export 'package:parser_core/src/merchant/merchant_data.dart'
    show DirectoryEntry;

/// Known merchants: the words that identify them, their display name, and
/// their category (FR-06-09). Keys are upper case. A single-word key must equal
/// one token of the merchant string; a multi-word key must appear as a phrase.
/// Tokens prevent "OLA" from matching "COCA COLA".
abstract final class MerchantDirectory {
  static final Map<String, DirectoryEntry> _byToken = {};
  static final List<(String, DirectoryEntry)> _byPhrase = _build();
  static final Map<String, Category> _keyword = {
    for (final (cat, words) in keywordRows)
      for (final w in words) w: cat,
  };

  static List<(String, DirectoryEntry)> _build() {
    final phrases = <(String, DirectoryEntry)>[];
    for (final (keys, entry) in directoryRows) {
      for (final k in keys) {
        if (k.contains(' ')) {
          phrases.add((k, entry));
        } else {
          _byToken.putIfAbsent(k, () => entry);
        }
      }
    }
    // Longest phrase first so "SWIGGY INSTAMART" wins over "SWIGGY"; a stable
    // sort, as the Kotlin `sortByDescending` is.
    final indexed = [for (var i = 0; i < phrases.length; i++) (i, phrases[i])]
      ..sort((a, b) {
        final byLength = b.$2.$1.length.compareTo(a.$2.$1.length);
        return byLength != 0 ? byLength : a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }

  /// The directory entry for [upper] (an upper-case merchant string) split into
  /// [tokens]: a phrase first, then a token.
  static DirectoryEntry? lookup(String upper, List<String> tokens) {
    for (final (phrase, entry) in _byPhrase) {
      if (upper.contains(phrase)) return entry;
    }
    for (final t in tokens) {
      final e = _byToken[t];
      if (e != null) return e;
    }
    return null;
  }

  /// The category a generic word in [tokens] gives away, or null.
  static Category? categoryByKeyword(List<String> tokens) {
    for (final t in tokens) {
      final c = _keyword[t];
      if (c != null) return c;
    }
    return null;
  }
}

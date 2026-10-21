/// Case-insensitive regex (FR-06-20: Java `CASE_INSENSITIVE` parity).
RegExp rx(String pattern) => RegExp(pattern, caseSensitive: false);

/// A regex that must match the whole input (the Kotlin `Regex.matches`).
RegExp rxFull(String pattern) => rx('^(?:$pattern)\$');

/// Every match of [re] in [text], starting the scan at [start] while still
/// letting look-behinds see the text before it.
Iterable<RegExpMatch> allMatchesFrom(RegExp re, String text, [int start = 0]) =>
    re.allMatches(text, start);

/// The first match of [re] at or after [start], or null.
RegExpMatch? findFrom(RegExp re, String text, [int start = 0]) {
  final it = re.allMatches(text, start).iterator;
  return it.moveNext() ? it.current : null;
}

/// A regex behind a cheap substring pre-check. Most patterns cannot match
/// most messages, and `String.contains` on the lowercased text is far cheaper
/// than a regex scan that fails (FR-06-21).
///
/// Every string the regex can match must contain at least one of [needles]
/// (lowercase), otherwise the guard would hide real matches.
class Guarded {
  /// Compiles [pattern] behind [needles].
  Guarded(String pattern, [this.needles = const []]) : regex = rx(pattern);

  /// The compiled pattern.
  final RegExp regex;

  /// Lowercase substrings, at least one of which any match contains.
  final List<String> needles;

  /// Whether the pre-check lets the regex run on [lower].
  bool allows(String lower) {
    if (needles.isEmpty) return true;
    for (final n in needles) {
      if (lower.contains(n)) return true;
    }
    return false;
  }

  /// Whether the pattern matches anywhere in [text].
  bool containsMatchIn(String text, String lower) =>
      allows(lower) && regex.hasMatch(text);

  /// The first match at or after [start].
  RegExpMatch? find(String text, String lower, [int start = 0]) =>
      allows(lower) ? findFrom(regex, text, start) : null;

  /// All matches.
  Iterable<RegExpMatch> findAll(String text, String lower) =>
      allows(lower) ? regex.allMatches(text) : const <RegExpMatch>[];
}

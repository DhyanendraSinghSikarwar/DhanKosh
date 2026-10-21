/// Removes any of the characters in [chars] from both ends of [s]
/// (the Kotlin `String.trim(vararg chars)`).
String trimChars(String s, String chars) {
  var start = 0;
  var end = s.length;
  while (start < end && chars.contains(s[start])) {
    start++;
  }
  while (end > start && chars.contains(s[end - 1])) {
    end--;
  }
  return s.substring(start, end);
}

/// [s] with its first character upper-cased.
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Whether [c] (one character) is a letter.
bool isLetter(String c) => c.toLowerCase() != c.toUpperCase();

/// Whether [c] (one character) is an ASCII digit.
bool isDigit(String c) {
  final u = c.codeUnitAt(0);
  return u >= 0x30 && u <= 0x39;
}

/// Whether [c] (one character) is a letter or a digit.
bool isLetterOrDigit(String c) => isLetter(c) || isDigit(c);

/// Only the letters and digits of [s].
String lettersAndDigits(String s) {
  final b = StringBuffer();
  for (final r in s.split('')) {
    if (isLetterOrDigit(r)) b.write(r);
  }
  return b.toString();
}

/// The last [n] characters of [s] (all of it when shorter).
String takeLast(String s, int n) =>
    s.length <= n ? s : s.substring(s.length - n);

/// Group [n] of [m], or an empty string when it did not take part.
String grp(Match m, int n) => m.group(n) ?? '';

/// The first non-empty capture group of [m], or null.
String? firstGroup(Match m) {
  for (var i = 1; i <= m.groupCount; i++) {
    final g = m.group(i);
    if (g != null && g.isNotEmpty) return g;
  }
  return null;
}

/// Enum <-> database text. Names are stored as `SNAKE_UPPER` (the Room format:
/// `emiLoan` <-> `EMI_LOAN`, `autoDebit` <-> `AUTO_DEBIT`).
String enumToDb(Enum e) =>
    e.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();

/// Reads [text] back to a value of [values]; [fallback] when unknown or null.
T enumFromDb<T extends Enum>(List<T> values, String? text, T fallback) {
  if (text == null) return fallback;
  for (final v in values) {
    if (enumToDb(v) == text) return v;
  }
  return fallback;
}

/// Like [enumFromDb] but null stays null and unknown text is null.
T? enumFromDbOrNull<T extends Enum>(List<T> values, String? text) {
  if (text == null) return null;
  for (final v in values) {
    if (enumToDb(v) == text) return v;
  }
  return null;
}

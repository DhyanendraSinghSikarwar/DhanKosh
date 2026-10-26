/// Makes anything loggable safe: only short, token-like values survive
/// (FR-35-05..FR-35-07). Messages, amounts, account numbers, UPI ids, emails
/// and names must never reach the file.
class LogSanitizer {
  const LogSanitizer._();

  /// Longest value kept.
  static const maxValueLength = 40;

  /// Longest key or code kept.
  static const maxKeyLength = 32;

  static final _digitRun = RegExp(r'\d{6,}');
  static final _decimal = RegExp(r'\d+[.,]\d{2}(?!\d)');
  static final _safeChars = RegExp(r'^[A-Za-z0-9_.:/\-]+$');
  static final _longToken = RegExp('[A-Za-z0-9]{20,}');
  static final _keyBad = RegExp('[^a-z0-9_.]');

  /// A code or key: lower-case token, never free text.
  static String key(String raw) {
    final k = raw.toLowerCase().replaceAll(_keyBad, '_');
    final cut = k.length > maxKeyLength ? k.substring(0, maxKeyLength) : k;
    return cut.isEmpty ? '_' : cut;
  }

  /// A field value. Free text, emails, UPI ids, long numbers and amounts are
  /// replaced by a marker.
  static String value(Object? raw) {
    final v = '${raw ?? ''}'.trim();
    if (v.isEmpty) return '-';
    if (v.length > maxValueLength) return '[long]';
    if (v.contains('@')) return '[redacted]';
    if (_decimal.hasMatch(v)) return '[num]';
    if (!_safeChars.hasMatch(v)) return '[text]';
    if (_longToken.hasMatch(v)) return '[long]';
    return v.replaceAll(_digitRun, '[num]');
  }

  /// Sanitised copy of [fields].
  static Map<String, String> fields(Map<String, Object?>? fields) => {
        for (final e in (fields ?? const <String, Object?>{}).entries)
          key(e.key): value(e.value),
      };
}

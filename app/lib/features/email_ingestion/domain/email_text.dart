/// Turns mail bodies into parser-ready text (FR-03-15). Pure functions.
abstract final class EmailText {
  static const _minPlain = 30;

  /// plain if its trimmed length >= 30, else HTML converted, else short plain.
  static String choose(String plain, String? html) {
    if (plain.trim().length >= _minPlain) return plain.trim();
    if (html != null && html.trim().isNotEmpty) {
      final t = fromHtml(html);
      if (t.isNotEmpty) return t;
    }
    return plain.trim();
  }

  static final _drop = RegExp(
    r'<(script|style|head)\b[^>]*>.*?</\1\s*>|<!--.*?-->',
    caseSensitive: false,
    dotAll: true,
  );
  static final _blockOpen = RegExp(
    r'<(?:p|div|tr|li|h[1-6]|table)\b[^>]*>',
    caseSensitive: false,
  );
  static final _br = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final _cellClose = RegExp(r'</t[dh]\s*>', caseSensitive: false);
  static final _tag = RegExp('<[^>]*>');
  static final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);');

  static const _named = <String, String>{
    'nbsp': ' ',
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'rupee': '₹',
    'ndash': '-',
    'mdash': '-',
  };

  /// HTML to text: drops script/style/head, keeps line and field boundaries.
  static String fromHtml(String html) {
    var s = html
        .replaceAll(_drop, ' ')
        .replaceAllMapped(_blockOpen, (m) => '\n${m[0]}')
        .replaceAllMapped(_br, (m) => '${m[0]}\n')
        .replaceAllMapped(_cellClose, (m) => '${m[0]} ')
        .replaceAll(_tag, '');
    s = s.replaceAllMapped(_entity, (m) {
      final e = m[1]!;
      if (e.startsWith('#x')) {
        final c = int.tryParse(e.substring(2), radix: 16);
        return c == null ? m[0]! : String.fromCharCode(c);
      }
      if (e.startsWith('#')) {
        final c = int.tryParse(e.substring(1));
        return c == null ? m[0]! : String.fromCharCode(c);
      }
      return _named[e.toLowerCase()] ?? m[0]!;
    });
    final out = <String>[];
    for (final raw in s.split(RegExp(r'\r?\n'))) {
      final line = raw.replaceAll(RegExp(r'[ \t ]+'), ' ').trim();
      if (line.isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
      out.add(line);
    }
    return out.join('\n').trim();
  }
}

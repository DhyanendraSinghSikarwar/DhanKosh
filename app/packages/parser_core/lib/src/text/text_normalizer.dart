import 'package:parser_core/src/text/rx.dart';

/// Produces the single canonical form every extractor works on: one line,
/// single spaces, no invisible characters, and every rupee spelling written as
/// "INR " (FR-06-01).
abstract final class TextNormalizer {
  // Zero width space, non-joiner, joiner, word joiner, BOM, soft hyphen.
  static const _zeroWidth = {0x200b, 0x200c, 0x200d, 0x2060, 0xfeff, 0xad};
  // No-break space, figure space, narrow no-break space, tab, VT, FF.
  static const _oddSpaces = {0xa0, 0x2007, 0x202f, 0x09, 0x0b, 0x0c};
  static const _sentenceEnd = '.!?:,;';
  static final RegExp _currency =
      rx(r'(?:₹|\bRs\.?|\bINR\.?)\s*[:.]?\s*(?=-?\d)');

  // Where a bank email's footer begins: support numbers, disclaimers, and
  // promos that would otherwise trip the rejection rules.
  static final RegExp _emailFooter = rx(
    r"\b(?:if you (?:did not|have not|haven't|do not)|if this (?:transaction|txn) (?:was|is) not|"
    'in case you have not|this is an? (?:system|computer|auto)|please do not reply|disclaimer|'
    'warm regards|regards,|thank you for banking|to unsubscribe|never share your|'
    'for any (?:queries|query|clarification))',
  );
  static const _emailMaxChars = 3000;
  static const _emailMinBody = 40;

  /// Cleans [raw] into the canonical one-line form.
  static String normalize(String raw) {
    if (raw.isEmpty) return raw;
    // One pass: drop invisible characters, collapse runs of space, and turn a
    // line break into a sentence end, since most SMS templates use line
    // breaks as field separators.
    final sb = StringBuffer();
    var last = '';
    var space = false;
    var lineBreak = false;
    for (final unit in raw.codeUnits) {
      final c = String.fromCharCode(unit);
      if (unit == 0x0a) {
        lineBreak = true;
      } else if (unit == 0x0d || _zeroWidth.contains(unit)) {
        continue;
      } else if (unit == 0x20 || _oddSpaces.contains(unit)) {
        space = true;
      } else {
        if (last.isNotEmpty) {
          if (lineBreak) {
            sb.write(_sentenceEnd.contains(last) ? ' ' : '. ');
          } else if (space) {
            sb.write(' ');
          }
        }
        space = false;
        lineBreak = false;
        sb.write(c);
        last = c;
      }
    }
    return sb.toString().replaceAll(_currency, 'INR ');
  }

  /// Cuts an already-normalized email body down to its transaction paragraph.
  static String trimEmail(String normalized) {
    final capped = normalized.length > _emailMaxChars
        ? normalized.substring(0, _emailMaxChars)
        : normalized;
    for (final m in _emailFooter.allMatches(capped)) {
      if (m.start >= _emailMinBody) return capped.substring(0, m.start).trim();
    }
    return capped;
  }
}

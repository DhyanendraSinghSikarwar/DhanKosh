import 'package:parser_core/parser_core.dart';

/// IST, as the Kotlin tests' `ZoneId.of("Asia/Kolkata")`.
const Duration ist = Duration(hours: 5, minutes: 30);

/// Epoch ms of a local IST date and time.
int istMs(int y, int m, int d, [int h = 0, int min = 0]) =>
    epochOf(CivilDate(y, m, d), CivilTime(h, min), ist);

/// Removes the common leading indentation and surrounding blank lines (the
/// Kotlin `trimIndent`).
String dedent(String s) {
  final lines = s.split('\n');
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  var indent = -1;
  for (final l in lines) {
    if (l.trim().isEmpty) continue;
    final n = l.length - l.trimLeft().length;
    if (indent < 0 || n < indent) indent = n;
  }
  if (indent <= 0) return lines.join('\n');
  return lines
      .map((l) => l.length >= indent ? l.substring(indent) : l.trimLeft())
      .join('\n');
}

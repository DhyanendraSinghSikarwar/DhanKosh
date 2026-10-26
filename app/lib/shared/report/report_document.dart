/// One block of a report: a heading, optional column titles and rows. With no
/// [columns] the rows are label/value pairs (FR-24-29).
class ReportSection {
  /// Creates a section.
  const ReportSection({
    required this.heading,
    required this.rows,
    this.columns = const [],
    this.note,
  });

  /// Section title.
  final String heading;

  /// Column titles; empty for label/value rows.
  final List<String> columns;

  /// Cell text per row.
  final List<List<String>> rows;

  /// Small text under the rows.
  final String? note;
}

/// A printable report, independent of the PDF library (FR-24-29).
class ReportDocument {
  /// Creates a document.
  const ReportDocument({
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.footer,
    required this.fileStem,
  });

  /// Page title.
  final String title;

  /// Period or date line.
  final String subtitle;

  /// Body blocks, in order.
  final List<ReportSection> sections;

  /// Disclaimer or privacy line printed on every page.
  final String footer;

  /// File name without extension.
  final String fileStem;
}

/// Rupees from paise by integer math, en-IN grouping, ASCII only so the
/// built-in PDF fonts can draw it: `Rs 1,23,456.50`.
String reportMoney(int minor, {bool paise = true}) {
  final abs = minor.abs();
  final whole = _group((abs ~/ 100).toString());
  final p = (abs % 100).toString().padLeft(2, '0');
  final sign = minor < 0 ? '-' : '';
  return paise ? '${sign}Rs $whole.$p' : '${sign}Rs $whole';
}

String _group(String digits) {
  if (digits.length <= 3) return digits;
  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final first = head.length.isOdd ? 1 : 2;
  final buf = StringBuffer(head.substring(0, first));
  for (var i = first; i < head.length; i += 2) {
    buf
      ..write(',')
      ..write(head.substring(i, i + 2));
  }
  return '$buf,$tail';
}

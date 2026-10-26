import 'dart:typed_data';

import 'package:hisaab/shared/report/report_document.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Draws a [ReportDocument] as an A4 PDF on the device (FR-24-29). Nothing is
/// sent anywhere. [compress] is off only in tests, to search the text.
Future<Uint8List> renderReportPdf(
  ReportDocument source, {
  bool compress = true,
}) async {
  final d = _latin(source);
  final doc = pw.Document(
    compress: compress,
    title: d.title,
    creator: 'DhanKosh',
  );
  const grey = PdfColors.grey700;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            d.footer,
            style: const pw.TextStyle(fontSize: 8, color: grey),
          ),
          pw.Text(
            'Page ${c.pageNumber} of ${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: grey),
          ),
        ],
      ),
      build: (c) => [
        pw.Text(
          d.title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(d.subtitle, style: const pw.TextStyle(color: grey)),
        for (final s in d.sections) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            s.heading,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          if (s.rows.isEmpty)
            pw.Text('Nothing to show', style: const pw.TextStyle(color: grey))
          else if (s.columns.isEmpty)
            pw.TableHelper.fromTextArray(
              data: s.rows,
              border: null,
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {1: pw.Alignment.centerRight},
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 2),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: s.columns,
              data: s.rows,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellAlignments: {
                for (var i = 1; i < s.columns.length; i++)
                  i: pw.Alignment.centerRight,
              },
            ),
          if (s.note != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              s.note!,
              style: const pw.TextStyle(fontSize: 9, color: grey),
            ),
          ],
        ],
      ],
    ),
  );
  return await doc.save();
}

String _s(String v) =>
    String.fromCharCodes(v.runes.map((r) => r > 255 ? 0x3f : r));

/// The built-in PDF fonts draw Latin-1 only; other characters become `?`.
ReportDocument _latin(ReportDocument d) => ReportDocument(
      title: _s(d.title),
      subtitle: _s(d.subtitle),
      footer: _s(d.footer),
      fileStem: d.fileStem,
      sections: [
        for (final s in d.sections)
          ReportSection(
            heading: _s(s.heading),
            columns: s.columns.map(_s).toList(),
            rows: [
              for (final r in s.rows) r.map(_s).toList(),
            ],
            note: s.note == null ? null : _s(s.note!),
          ),
      ],
    );

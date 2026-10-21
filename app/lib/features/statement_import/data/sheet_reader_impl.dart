import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

/// [SheetReader] over the `excel` package (XLSX only; XLS is unsupported).
class SheetReaderImpl implements SheetReader {
  /// Creates the reader.
  const SheetReaderImpl();

  @override
  List<List<String>> xlsxRows(Uint8List bytes) {
    final Excel book;
    try {
      book = Excel.decodeBytes(bytes);
    } on Object {
      throw const FormatException('Unreadable spreadsheet');
    }
    return [
      for (final sheet in book.tables.values)
        for (final row in sheet.rows) [for (final c in row) _cell(c?.value)],
    ];
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _cell(CellValue? v) => switch (v) {
        null => '',
        TextCellValue() => v.toString().trim(),
        IntCellValue(:final value) => '$value',
        DoubleCellValue(:final value) =>
          value == value.truncateToDouble() && value.abs() < 1e15
              ? value.toInt().toString()
              : value.toString(),
        DateCellValue(:final year, :final month, :final day) =>
          '${_two(day)}/${_two(month)}/$year',
        DateTimeCellValue(:final year, :final month, :final day) =>
          '${_two(day)}/${_two(month)}/$year',
        _ => '',
      };
}

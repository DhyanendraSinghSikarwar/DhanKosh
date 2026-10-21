import 'package:parser_core/parser_core.dart';

/// Exact export columns, in order (FR-24-03).
const csvHeader = [
  'date',
  'amount',
  'currency',
  'type',
  'bank',
  'account_last4',
  'account_kind',
  'merchant',
  'category',
  'channel',
  'reference',
  'balance',
  'upi_id',
  'note',
  'hash',
];

/// Message for a file without date, amount and type (FR-24-07).
const csvNotExport =
    'Not a DhanKosh export: needs date, amount and type columns';

/// Rows read from a CSV and the count of unreadable lines.
class CsvImportResult {
  /// Creates a result.
  const CsvImportResult({required this.rows, required this.badLines});

  /// Readable rows.
  final List<ParsedTransaction> rows;

  /// Lines skipped as unreadable.
  final int badLines;
}

/// What an import changed (FR-24-13).
class ImportReport {
  /// Creates a report.
  const ImportReport({
    required this.inserted,
    required this.skipped,
    this.merged = 0,
    this.flagged = 0,
    this.badLines = 0,
  });

  /// New rows.
  final int inserted;

  /// Rows already present.
  final int skipped;

  /// Rows merged into an existing transaction.
  final int merged;

  /// Rows sent to review as possible duplicates.
  final int flagged;

  /// Unreadable lines.
  final int badLines;

  /// "Imported 3, skipped 2 already present, 1 unreadable lines".
  String get message => 'Imported $inserted, skipped '
      '${skipped + merged} already present'
      '${flagged > 0 ? ', $flagged to review' : ''}'
      '${badLines > 0 ? ', $badLines unreadable lines' : ''}';
}

/// Picks and writes files through the system pickers (FR-24-02/06).
abstract interface class BackupFileGateway {
  /// Saves [bytes] as [fileName]; returns the saved name, or null on cancel.
  Future<String?> save(String fileName, List<int> bytes);

  /// Picks a CSV and returns its text, or null on cancel.
  Future<String?> pickText();
}

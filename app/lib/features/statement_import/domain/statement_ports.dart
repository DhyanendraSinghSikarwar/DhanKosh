import 'dart:typed_data';

/// A file the user picked (or an email attachment).
class PickedFile {
  /// Creates a file.
  const PickedFile({required this.name, required this.bytes});

  /// File name with extension.
  final String name;

  /// Whole content.
  final Uint8List bytes;
}

/// Chooses a statement file (system document picker; FR-05-01).
abstract interface class FileSource {
  /// The chosen file, or null when cancelled.
  Future<PickedFile?> pick();
}

/// Why PDF text could not be read (FR-05-02).
enum PdfFailure { passwordRequired, wrongPassword, unreadable, scanned }

/// Thrown by [PdfTextReader] with a [PdfFailure].
class PdfReadException implements Exception {
  /// Creates the exception.
  const PdfReadException(this.failure);

  /// Reason.
  final PdfFailure failure;

  @override
  String toString() => 'PdfReadException(${failure.name})';
}

/// Reads PDF text on the device (native bridge behind it).
abstract interface class PdfTextReader {
  /// Text of [bytes] opened with [password] (null = none). Throws
  /// [PdfReadException].
  Future<String> extractText(Uint8List bytes, {String? password});
}

/// File types a statement can be (FR-05-01, FR-05-05).
enum StatementFileType { pdf, xlsx, xls, csv, protectedSheet, unknown }

/// Spreadsheet cells of a statement as text rows.
abstract interface class SheetReader {
  /// Rows of every sheet of an XLSX; throws [FormatException] when it cannot
  /// be read. CSV text is read by the use case.
  List<List<String>> xlsxRows(Uint8List bytes);
}

/// App-private, non-backed-up statement files named by hash (FR-05-21).
abstract interface class StatementFileStore {
  /// Stores [bytes] under [name]; returns the stored path.
  Future<String> save(String name, Uint8List bytes);

  /// Bytes at [path], or null when missing.
  Future<Uint8List?> read(String path);

  /// Removes the file at [path] (no error when missing).
  Future<void> delete(String path);
}

/// Works out the type from the bytes, then the name (FR-05-01).
StatementFileType sniffStatement(Uint8List b, String name) {
  bool starts(List<int> sig) {
    if (b.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[i] != sig[i]) return false;
    }
    return true;
  }

  if (starts([0x25, 0x50, 0x44, 0x46])) return StatementFileType.pdf;
  if (starts([0x50, 0x4b, 0x03, 0x04])) return StatementFileType.xlsx;
  if (starts([0xd0, 0xcf, 0x11, 0xe0])) {
    // OLE container: an encrypted XLSX carries an "EncryptedPackage" stream.
    final marker = [
      for (final c in 'EncryptedPackage'.codeUnits) ...[c, 0],
    ];
    return _contains(b, marker)
        ? StatementFileType.protectedSheet
        : StatementFileType.xls;
  }
  final sample = b.length > 4096 ? b.sublist(0, 4096) : b;
  if (sample.isNotEmpty &&
      !sample.contains(0) &&
      name.toLowerCase().endsWith('.csv')) {
    return StatementFileType.csv;
  }
  return StatementFileType.unknown;
}

bool _contains(Uint8List b, List<int> needle) {
  final n = needle.length;
  for (var i = 0; i + n <= b.length; i++) {
    var ok = true;
    for (var j = 0; j < n; j++) {
      if (b[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

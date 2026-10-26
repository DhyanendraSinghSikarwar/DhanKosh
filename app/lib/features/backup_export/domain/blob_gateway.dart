import 'dart:typed_data';

/// Saves and picks binary files through the system pickers (FR-24-28); used
/// by encrypted backups and PDF reports.
abstract interface class BlobGateway {
  /// Saves [bytes] as [fileName] (MIME [mimeType]); returns the saved name,
  /// or null on cancel.
  Future<String?> saveFile(String fileName, List<int> bytes, String mimeType);

  /// Picks one file and returns its bytes, or null on cancel.
  Future<Uint8List?> pickBytes();
}

import 'dart:typed_data';

/// Hands a file to the system share sheet (FR-19-10). Nothing is uploaded by
/// the app; the user picks the target.
abstract interface class ShareGateway {
  /// Shares [bytes] as [fileName] (MIME [mimeType]). False when the sheet
  /// could not be shown.
  Future<bool> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? text,
  });
}

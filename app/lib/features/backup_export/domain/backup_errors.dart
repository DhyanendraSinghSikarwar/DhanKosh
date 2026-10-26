/// The file is not a DhanKosh backup, or is from a newer app (FR-24-21).
class BackupFormatException implements Exception {
  /// Creates the error.
  const BackupFormatException(this.message);

  /// Short, user-facing text.
  final String message;

  @override
  String toString() => message;
}

/// Wrong passphrase, or the file was changed (FR-24-20). AES-GCM cannot tell
/// the two apart, so one message covers both.
class BackupAuthException implements Exception {
  /// Creates the error.
  const BackupAuthException();

  /// User-facing text.
  static const text = 'Wrong passphrase, or the backup file is damaged';

  @override
  String toString() => text;
}

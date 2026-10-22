import 'dart:typed_data';

/// A statement file attached to an email (FR-03-16).
class EmailAttachment {
  /// Creates an attachment.
  const EmailAttachment({required this.name, required this.bytes});

  /// File name with extension.
  final String name;

  /// Decoded content.
  final Uint8List bytes;
}

/// Rules for which attachments are read as statements (memory 03 2.11).
abstract final class StatementAttachments {
  /// At most this many per mail (IMAP).
  static const maxPerMail = 5;

  /// Larger files are skipped, bytes (FR-05-22).
  static const maxBytes = 25 * 1024 * 1024;

  static final _name = RegExp(r'\.(pdf|xlsx|xlsm|xls|csv)$', caseSensitive: false);

  static const _mimes = {
    'application/pdf',
    'application/vnd.ms-excel',
    'text/csv',
    'application/csv',
    'text/comma-separated-values',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel.sheet.macroenabled.12',
  };

  /// True for a PDF or spreadsheet by [name] or [mime], with a size [size]
  /// within the cap (unknown size passes).
  static bool accepts({String? name, String? mime, int? size}) {
    if (size != null && size > maxBytes) return false;
    if (name != null && _name.hasMatch(name)) return true;
    final m = mime?.toLowerCase();
    return m != null && _mimes.contains(m);
  }

  /// [name] or a default for [mime] (`statement.pdf`, `statement.xls`).
  static String nameOf(String? name, String? mime) {
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return (mime ?? '').toLowerCase() == 'application/pdf'
        ? 'statement.pdf'
        : 'statement.xls';
  }
}

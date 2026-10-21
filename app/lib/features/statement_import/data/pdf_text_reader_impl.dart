import 'dart:typed_data';

import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/core/platform_channels/pdf_channel.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

/// [PdfTextReader] over the native `pdf` channel (FR-05-02).
class PdfTextReaderImpl implements PdfTextReader {
  /// Creates the reader.
  const PdfTextReaderImpl(this._channel);

  final PdfChannel _channel;

  @override
  Future<String> extractText(Uint8List bytes, {String? password}) async {
    try {
      return (await _channel.extractText(bytes: bytes, password: password))
          .text;
    } on ChannelFailure catch (e) {
      throw PdfReadException(
        switch (e.code) {
          'password_required' => PdfFailure.passwordRequired,
          'wrong_password' => PdfFailure.wrongPassword,
          'scanned' => PdfFailure.scanned,
          _ => PdfFailure.unreadable,
        },
      );
    }
  }
}

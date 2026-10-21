import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Text read from a PDF (`pages` as counted by the native reader).
class PdfText {
  /// Creates a result.
  const PdfText({required this.text, required this.pages});

  /// Position-sorted page text.
  final String text;

  /// Page count.
  final int pages;
}

/// Typed wrapper for the `pdf` platform channel (FR-05-02).
///
/// Native errors surface as `ChannelFailure` with code `password_required`,
/// `wrong_password`, `unreadable` or `scanned` (no text layer).
class PdfChannel extends ChannelBase {
  /// Creates the wrapper over the `pdf` channel.
  const PdfChannel() : super(_channel);

  /// The `pdf` method channel.
  static const MethodChannel _channel = MethodChannel(ChannelNames.pdf);

  /// Reads the text of a PDF given as [bytes] or a file [path]. [password] is
  /// omitted for the first, no-password try.
  Future<PdfText> extractText({
    Uint8List? bytes,
    String? path,
    String? password,
  }) async {
    final m = await invoke<Map<Object?, Object?>>('extractText', {
      if (bytes != null) 'bytes': bytes,
      if (path != null) 'path': path,
      if (password != null) 'password': password,
    });
    return PdfText(
      text: (m?['text'] ?? '').toString(),
      pages: (m?['pages'] as num?)?.toInt() ?? 0,
    );
  }
}

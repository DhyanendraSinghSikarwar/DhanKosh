import 'dart:io';

import 'package:hisaab/core/platform_channels/alerts_channel.dart';
import 'package:hisaab/features/statement_import/domain/shared_file_source.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

/// [SharedFileSource] over the Kotlin share-in copy (FR-05-26). The cache copy
/// is deleted after it is read.
class ChannelSharedFileSource implements SharedFileSource {
  /// Creates the source.
  const ChannelSharedFileSource([this._channel = const AlertsChannel()]);

  final AlertsChannel _channel;

  @override
  Future<PickedFile?> take() async {
    try {
      final path = await _channel.takeSharedFile();
      if (path == null) return null;
      final f = File(path);
      if (!f.existsSync()) return null;
      try {
        if (f.lengthSync() > maxStatementBytes) return null;
        final bytes = await f.readAsBytes();
        return PickedFile(
          name: f.uri.pathSegments.last,
          bytes: bytes,
        );
      } finally {
        try {
          f.deleteSync();
        } on FileSystemException {
          // Cache is cleared by the OS anyway.
        }
      }
    } on Object {
      return null;
    }
  }
}

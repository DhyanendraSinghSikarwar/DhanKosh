import 'dart:typed_data';

import 'package:hisaab/shared/ports/lock_skipper.dart';
import 'package:hisaab/shared/ports/share_gateway.dart';
import 'package:share_plus/share_plus.dart';

/// [ShareGateway] over `share_plus` (system share sheet, FR-19-10).
class SharePlusGateway implements ShareGateway {
  /// Creates the gateway; [lockSkipper] skips the app lock around the sheet.
  const SharePlusGateway({this.lockSkipper = const NoLockSkipper()});

  /// Skips the app lock for the hop to the share sheet (FR-25-06).
  final LockSkipper lockSkipper;

  @override
  Future<bool> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
    try {
      lockSkipper.skipNextLock();
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
          fileNameOverrides: [fileName],
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }
}

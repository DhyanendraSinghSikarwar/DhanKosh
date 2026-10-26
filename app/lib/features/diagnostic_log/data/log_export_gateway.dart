import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hisaab/features/diagnostic_log/domain/diagnostic_log_store.dart';
import 'package:hisaab/shared/ports/lock_skipper.dart';

/// [LogExportGateway] over the system save dialog; no storage permission.
class FilePickerLogExportGateway implements LogExportGateway {
  /// Creates the gateway.
  const FilePickerLogExportGateway({this.lockSkipper = const NoLockSkipper()});

  /// Skips the app lock around the picker (FR-25-06).
  final LockSkipper lockSkipper;

  @override
  Future<String?> save(String fileName, List<int> bytes) async {
    lockSkipper.skipNextLock();
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'text/plain',
    );
    if (uri == null) return null;
    final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return seg.isEmpty ? 'file' : seg.split('/').last;
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hisaab/features/backup_export/domain/backup_models.dart';

/// [BackupFileGateway] over the system pickers; no storage permission.
class FilePickerBackupGateway implements BackupFileGateway {
  /// Creates the gateway.
  const FilePickerBackupGateway();

  @override
  Future<String?> save(String fileName, List<int> bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'text/csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (uri == null) return null;
    final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return seg.isEmpty ? 'file' : seg.split('/').last;
  }

  @override
  Future<String?> pickText() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    if (f == null) return null;
    return utf8.decode(await f.readAsBytes(), allowMalformed: true);
  }
}

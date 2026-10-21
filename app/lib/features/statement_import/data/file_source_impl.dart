import 'package:file_picker/file_picker.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

/// [FileSource] over the system document picker (FR-05-01); no storage
/// permission is needed.
class FileSourceImpl implements FileSource {
  /// Creates the source.
  const FileSourceImpl();

  @override
  Future<PickedFile?> pick() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'xlsx', 'xls', 'csv'],
    );
    if (f == null) return null;
    return PickedFile(name: f.name, bytes: await f.readAsBytes());
  }
}

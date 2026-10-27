import 'package:file_picker/file_picker.dart';
import 'package:hisaab/features/transactions_ledger/domain/ocr_port.dart';
import 'package:hisaab/shared/ports/lock_skipper.dart';

/// Chooses an image with the system picker (FR-08-12, FR-25-06).
class FilePickerScreenshotSource implements ScreenshotSource {
  /// Creates the source.
  const FilePickerScreenshotSource({
    this.lockSkipper = const NoLockSkipper(),
  });

  /// Skips the app lock around the picker.
  final LockSkipper lockSkipper;

  @override
  Future<String?> pick() async {
    lockSkipper.skipNextLock();
    final f = await FilePicker.pickFile(type: FileType.image);
    return f?.path;
  }
}

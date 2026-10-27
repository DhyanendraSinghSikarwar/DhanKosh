import 'dart:io';
import 'dart:typed_data';

import 'package:hisaab/features/profile/domain/profile_photo.dart';
import 'package:path_provider/path_provider.dart';

/// [ProfilePhotoStore] in the app's private documents folder.
class ProfilePhotoStoreImpl implements ProfilePhotoStore {
  /// Creates the store; [directory] is injectable for tests.
  ProfilePhotoStoreImpl({Future<Directory> Function()? directory})
      : _dir = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _dir;

  @override
  Future<String> save(Uint8List png) async {
    final d = Directory('${(await _dir()).path}/profile');
    await d.create(recursive: true);
    final f = File(
      '${d.path}/photo_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await f.writeAsBytes(png, flush: true);
    return f.path;
  }

  @override
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

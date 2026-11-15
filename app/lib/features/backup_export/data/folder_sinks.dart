import 'dart:io';
import 'dart:typed_data';

import 'package:hisaab/core/platform_channels/folder_channel.dart';
import 'package:hisaab/features/backup_export/domain/scheduled_backup.dart';

/// A folder on the phone's own storage (the app's private `backups` folder).
class DirectorySink implements BackupSink {
  /// Creates the sink over the folder [dir] returns.
  const DirectorySink(this.id, this.dir);

  @override
  final String id;

  /// Where files go.
  final Future<Directory> Function() dir;

  @override
  Future<Set<String>> list() async {
    final d = await dir();
    if (!d.existsSync()) return {};
    return {
      for (final f in d.listSync())
        if (f is File) f.uri.pathSegments.last,
    };
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    final d = await dir();
    d.createSync(recursive: true);
    final tmp = File('${d.path}/$name.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename('${d.path}/$name');
  }
}

/// A folder the user picked with the system picker, on the phone or in a
/// cloud provider such as Google Drive.
class TreeSink implements BackupSink {
  /// Creates the sink over the tree address [uri].
  const TreeSink(this.id, this.uri, this._channel);

  @override
  final String id;

  /// Persisted tree address.
  final String uri;

  final FolderChannel _channel;

  @override
  Future<Set<String>> list() => _channel.list(uri);

  @override
  Future<void> write(String name, Uint8List bytes) =>
      _channel.write(uri, name, bytes);
}

import 'dart:io';
import 'dart:typed_data';

import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// [StatementFileStore] in the app-private support directory (FR-05-21).
/// Backup is off app-wide (`allowBackup=false`); files never leave the phone.
class StatementFileStoreImpl implements StatementFileStore {
  /// Creates the store; [root] overrides the directory (tests).
  const StatementFileStoreImpl({this.root});

  /// Directory override.
  final Directory? root;

  Future<Directory> _dir() async {
    final base = root ?? await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'statements'));
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  @override
  Future<String> save(String name, Uint8List bytes) async {
    final f = File(p.join((await _dir()).path, p.basename(name)));
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  @override
  Future<Uint8List?> read(String path) async {
    final f = File(path);
    return f.existsSync() ? await f.readAsBytes() : null;
  }

  @override
  Future<void> delete(String path) async {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }
}

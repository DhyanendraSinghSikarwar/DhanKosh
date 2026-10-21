import 'dart:io';

import 'package:hisaab/features/localization/domain/language.dart';

/// Packs as `<dir>/<code>.json` in app-private storage (FR-29-07, FR-29-18).
class LanguagePackStoreImpl implements LanguagePackStore {
  /// Creates the store; [dir] resolves the private `lang` directory.
  LanguagePackStoreImpl(this.dir);

  /// Directory resolver.
  final Future<Directory> Function() dir;

  Future<File> _file(Language l) async =>
      File('${(await dir()).path}/${l.code}.json');

  @override
  Future<Set<Language>> downloaded() async {
    final out = <Language>{};
    for (final l in Language.values) {
      if (!l.builtIn && (await _file(l)).existsSync()) out.add(l);
    }
    return out;
  }

  @override
  Future<String?> read(Language l) async {
    final f = await _file(l);
    return f.existsSync() ? await f.readAsString() : null;
  }

  @override
  Future<void> write(Language l, String body) async {
    final f = await _file(l);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(body, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> delete(Language l) async {
    final f = await _file(l);
    if (f.existsSync()) await f.delete();
  }
}

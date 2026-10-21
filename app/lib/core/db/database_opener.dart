import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:hisaab/core/db/db_key_store.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

/// Opens the encrypted on-device database (SQLCipher, key from [keyStore]).
///
/// Throws [StorageFailure] if the linked SQLite is not SQLCipher.
QueryExecutor openEncryptedDatabase(DbKeyStore keyStore) {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);

    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'hisaab.db'));
    final key = await keyStore.getOrCreateKey();

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        final version = db.select('PRAGMA cipher_version;');
        if (version.isEmpty) {
          throw const StorageFailure('SQLCipher is not available');
        }
        db.execute("PRAGMA key = \"x'$key'\";");
      },
    );
  });
}

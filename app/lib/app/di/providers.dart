import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/database_opener.dart';
import 'package:hisaab/core/db/db_key_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

// App-level dependency wiring (repositories, database, channels) lives here.
// Presentation depends on domain interfaces; data implementations are bound
// in this folder (plan.md section 3).

/// Source of the SQLCipher key; override in tests.
@Riverpod(keepAlive: true)
DbKeyStore dbKeyStore(Ref ref) => SecureStorageDbKeyStore();

/// The encrypted database, closed when the container is disposed.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(openEncryptedDatabase(ref.watch(dbKeyStoreProvider)));
  ref.onDispose(db.close);
  return db;
}

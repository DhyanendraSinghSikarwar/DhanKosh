import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/database_opener.dart';
import 'package:hisaab/core/db/db_key_store.dart';
import 'package:hisaab/features/accounts_management/data/account_repository_impl.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/categorization/data/category_repository_impl.dart';
import 'package:hisaab/features/categorization/domain/category_repository.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_repository_impl.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';
import 'package:hisaab/features/transactions_ledger/data/transaction_repository_impl.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
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

/// Accounts and cards (F-13).
@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) =>
    AccountRepositoryImpl(ref.watch(appDatabaseProvider));

/// Category rules and custom categories (F-09).
@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) =>
    CategoryRepositoryImpl(ref.watch(appDatabaseProvider));

/// Key-value settings (F-26).
@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepositoryImpl(ref.watch(appDatabaseProvider));

/// The single ledger write path and its read queries (F-08, F-07).
@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) =>
    TransactionRepositoryImpl(
      ref.watch(appDatabaseProvider),
      accounts: ref.watch(accountRepositoryProvider),
      categories: ref.watch(categoryRepositoryProvider),
    );

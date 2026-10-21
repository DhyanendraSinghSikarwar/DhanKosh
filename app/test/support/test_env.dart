import 'package:drift/native.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/accounts_management/data/account_repository_impl.dart';
import 'package:hisaab/features/categorization/data/category_repository_impl.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_repository_impl.dart';
import 'package:hisaab/features/transactions_ledger/data/transaction_repository_impl.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:parser_core/parser_core.dart';

/// In-memory database with the real repositories.
class TestEnv {
  TestEnv() : db = AppDatabase(NativeDatabase.memory()) {
    accounts = AccountRepositoryImpl(db, now: () => clock);
    categories = CategoryRepositoryImpl(db);
    settings = SettingsRepositoryImpl(db);
    txs = TransactionRepositoryImpl(
      db,
      accounts: accounts,
      categories: categories,
      now: () => clock,
    );
  }

  final AppDatabase db;
  late final AccountRepositoryImpl accounts;
  late final CategoryRepositoryImpl categories;
  late final SettingsRepositoryImpl settings;
  late final TransactionRepositoryImpl txs;
  int clock = 1790310600000;

  Future<IngestResult> ingest(
    ParsedTransaction p, {
    String? id,
    String? raw,
    int? accountId,
  }) =>
      txs.ingest(
        IngestItem(
          parsed: p,
          sourceMessageId: id ?? 'm-${p.source.name}-${p.transactionHash}',
          rawText: raw,
          accountId: accountId,
        ),
      );

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
          .read<int>('c');

  Future<void> close() => db.close();
}

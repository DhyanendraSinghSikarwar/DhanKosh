import 'dart:convert';
import 'dart:isolate';

import 'package:hisaab/features/backup_export/data/csv_codec.dart';
import 'package:hisaab/features/backup_export/domain/backup_models.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';

/// Epoch ms of the last successful export; 0 when never.
const lastExportKey = SettingKey<int>('last_csv_export', 0);

/// CSV export and import over the single ledger write path (F-24).
class BackupService {
  /// Creates the service.
  BackupService(TransactionRepository txs, SettingsRepository settings)
      : _txs = txs,
        _settings = settings;

  final TransactionRepository _txs;
  final SettingsRepository _settings;

  /// Every transaction including review rows, oldest first (FR-24-03).
  Future<List<LedgerTx>> allTransactions() async {
    final main = await _txs.watch(const LedgerFilter()).first;
    final review =
        await _txs.watch(const LedgerFilter(kind: TxKind.review)).first;
    final byId = {
      for (final t in [...main, ...review]) t.id: t,
    };
    return byId.values.toList();
  }

  /// The CSV text and its row count.
  Future<({String csv, int count})> buildCsv() async {
    final rows = await allTransactions();
    final csv = rows.length > 2000
        ? await Isolate.run(() => exportCsv(rows))
        : exportCsv(rows);
    return (csv: csv, count: rows.length);
  }

  /// Saves the CSV; returns the saved name, or null when cancelled.
  Future<({int count, String file})?> export(
    BackupFileGateway gateway, {
    required DateTime now,
  }) async {
    final built = await buildCsv();
    final name = 'hisaab-${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.csv';
    final saved = await gateway.save(name, utf8.encode(built.csv));
    if (saved == null) return null;
    await _settings.write(lastExportKey, now.millisecondsSinceEpoch);
    return (count: built.count, file: saved);
  }

  /// Parses [text] without writing anything (for the confirm dialog).
  Future<CsvImportResult> parse(String text) async => text.length > 200000
      ? await Isolate.run(() => importCsv(text))
      : importCsv(text);

  /// Ingests parsed rows through the ledger (FR-24-10/11); stable source
  /// ids make a second import add nothing.
  Future<ImportReport> ingest(CsvImportResult parsed) async {
    final report = await _txs.ingestBatch([
      for (final p in parsed.rows)
        IngestItem(parsed: p, sourceMessageId: 'csv:${p.transactionHash}'),
    ]);
    return ImportReport(
      inserted: report.inserted,
      skipped: report.skipped,
      merged: report.merged,
      flagged: report.flagged,
      badLines: parsed.badLines,
    );
  }
}

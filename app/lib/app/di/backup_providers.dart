import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/goals_providers.dart';
import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/sip_providers.dart';
import 'package:hisaab/features/backup_export/data/backup_data.dart';
import 'package:hisaab/features/backup_export/data/backup_service.dart';
import 'package:hisaab/features/backup_export/data/file_gateway.dart';
import 'package:hisaab/features/backup_export/data/full_backup_service.dart';
import 'package:hisaab/features/backup_export/data/report_service.dart';
import 'package:hisaab/features/backup_export/domain/backup_models.dart';
import 'package:hisaab/features/backup_export/domain/blob_gateway.dart';
import 'package:hisaab/features/backup_export/domain/full_backup.dart';

/// Pickers for the Backup screen; overridden in tests.
final backupFileGatewayProvider = Provider<BackupFileGateway>(
  (ref) => FilePickerBackupGateway(lockSkipper: ref.watch(lockSkipperProvider)),
);

/// CSV export and import (F-24).
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(transactionRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

/// Last export time in epoch ms, 0 when never.
final FutureProvider<int> lastExportProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(settingsRepositoryProvider).read(lastExportKey),
);

/// Binary picker and saver (encrypted backups, PDF reports).
final blobGatewayProvider = Provider<BlobGateway>(
  (ref) => FilePickerBackupGateway(lockSkipper: ref.watch(lockSkipperProvider)),
);

/// Repositories behind the full backup (F-24).
final backupDataProvider = Provider<BackupData>(
  (ref) => BackupData(
    BackupDeps(
      txs: ref.watch(transactionRepositoryProvider),
      accounts: ref.watch(accountRepositoryProvider),
      loans: ref.watch(loanAccountRepositoryProvider),
      categories: ref.watch(categoryRepositoryProvider),
      budgets: ref.watch(budgetRepositoryProvider),
      recurring: ref.watch(recurringRepositoryProvider),
      holdings: ref.watch(holdingRepositoryProvider),
      cards: ref.watch(cardDueRepositoryProvider),
      cardPaid: ref.watch(cardPaidStoreProvider),
      loanLinks: ref.watch(loanLinkRepositoryProvider),
      forex: ref.watch(forexRepositoryProvider),
      sips: ref.watch(sipRepositoryProvider),
      goals: ref.watch(goalRepositoryProvider),
      settings: ref.watch(settingsRepositoryProvider),
      reset: ref.watch(dataResetRepositoryProvider),
    ),
  ),
);

/// Encrypted full backup and restore (F-24).
final fullBackupServiceProvider = Provider<FullBackupPort>(
  (ref) => FullBackupService(
    ref.watch(backupDataProvider),
    (ms) => ref.read(settingsRepositoryProvider).write(lastFullBackupKey, ms),
  ),
);

/// Last encrypted backup time in epoch ms, 0 when never.
final FutureProvider<int> lastFullBackupProvider =
    FutureProvider.autoDispose<int>(
  (ref) => ref.watch(settingsRepositoryProvider).read(lastFullBackupKey),
);

/// PDF reports built on the device (F-24, F-19).
final reportServiceProvider = Provider<ReportService>(
  (ref) => ReportService(
    txs: ref.watch(transactionRepositoryProvider),
    budgets: ref.watch(budgetRepositoryProvider),
    holdings: ref.watch(holdingRepositoryProvider),
    netWorth: () async {
      try {
        return await ref.read(netWorthServiceProvider).watch().first;
      } on Object {
        return null;
      }
    },
  ),
);

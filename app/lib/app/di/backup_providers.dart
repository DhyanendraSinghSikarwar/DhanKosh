import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/backup_export/data/backup_service.dart';
import 'package:hisaab/features/backup_export/data/file_gateway.dart';
import 'package:hisaab/features/backup_export/domain/backup_models.dart';

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

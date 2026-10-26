import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/activity_log/data/activity_log_repository_impl.dart';
import 'package:hisaab/features/activity_log/domain/activity_logger.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/security_privacy/data/local_auth_app_lock_service.dart';
import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:hisaab/features/security_privacy/domain/security_settings.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'security_providers.g.dart';

/// System authentication (F-25).
@Riverpod(keepAlive: true)
AppLockService appLockService(Ref ref) => LocalAuthAppLockService();

/// Whether the phone can authenticate now (FR-25-02).
@riverpod
Future<AuthAvailability> authAvailability(Ref ref) =>
    ref.watch(appLockServiceProvider).availability();

/// The `app_lock` setting; loading until known (FR-25-08).
@Riverpod(keepAlive: true)
Stream<bool> appLockEnabled(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(SettingKeys.appLock);

/// Minutes away before the app locks again; 0 = immediately (FR-25-21).
@Riverpod(keepAlive: true)
Stream<int> autoLockMinutes(Ref ref) => ref
    .watch(settingsRepositoryProvider)
    .watch(SecuritySettings.autoLockMinutes);

/// Whether screenshots and the recents preview are blocked (FR-25-23).
@Riverpod(keepAlive: true)
Stream<bool> blockScreenshots(Ref ref) => ref
    .watch(settingsRepositoryProvider)
    .watch(SecuritySettings.blockScreenshots);

/// Stored activity log (F-22).
@Riverpod(keepAlive: true)
ActivityLogRepository activityLogRepository(Ref ref) =>
    ActivityLogRepositoryImpl(ref.watch(appDatabaseProvider));

/// Logger port handed to ingestion paths (FR-22-01).
@Riverpod(keepAlive: true)
ActivityLogger activityLogger(Ref ref) =>
    ref.watch(activityLogRepositoryProvider);

/// Newest log entries, live (FR-22-02).
@riverpod
Stream<List<ActivityEntry>> activityEntries(Ref ref) =>
    ref.watch(activityLogRepositoryProvider).watch();

/// Planned next SMS scan, epoch ms; 0 when unknown (FR-22-08).
const nextSmsSyncKey = SettingKey<int>('next_sms_sync_at', 0);

/// Planned next email sync, epoch ms; 0 when unknown (FR-22-08).
const nextEmailSyncKey = SettingKey<int>('next_email_sync_at', 0);

/// Records the next nightly run (the job syncs SMS then email); null clears
/// both (FR-22-08).
Future<void> recordNextSync(SettingsRepository settings, DateTime? next) async {
  final ms = next?.millisecondsSinceEpoch ?? 0;
  await settings.write(nextSmsSyncKey, ms);
  await settings.write(nextEmailSyncKey, ms);
}

/// Planned next SMS scan, epoch ms; 0 when unknown (FR-22-08).
@riverpod
Stream<int> nextSmsSync(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(nextSmsSyncKey);

/// Planned next email sync, epoch ms; 0 when unknown (FR-22-08).
@riverpod
Stream<int> nextEmailSync(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(nextEmailSyncKey);

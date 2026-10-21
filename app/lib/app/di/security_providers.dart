import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/activity_log/data/activity_log_repository_impl.dart';
import 'package:hisaab/features/activity_log/domain/activity_logger.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/security_privacy/data/local_auth_app_lock_service.dart';
import 'package:hisaab/features/security_privacy/domain/app_lock_service.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
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

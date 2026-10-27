import 'dart:async';

import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/app/di/log_providers.dart';
import 'package:hisaab/app/di/notification_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/app/di/sender_providers.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/core/platform_channels/background_channel.dart';
import 'package:hisaab/core/platform_channels/permissions_channel.dart';
import 'package:hisaab/core/platform_channels/sms_channel.dart';
import 'package:hisaab/features/onboarding_permissions/data/identity_store.dart';
import 'package:hisaab/features/onboarding_permissions/data/permission_repository_impl.dart';
import 'package:hisaab/features/onboarding_permissions/data/profile_store.dart';
import 'package:hisaab/features/onboarding_permissions/data/secure_store_impl.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/sms_permission_state.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/onboarding_permissions/domain/usecases/onboarding_usecases.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/settings_data_sources/domain/data_reset_repository.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_inbox_source_impl.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_live_source_impl.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_scan_scheduler_impl.dart';
import 'package:hisaab/features/sms_ingestion/data/sms_settings_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/handle_live_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/sms_engine.dart';
import 'package:hisaab/features/transactions_ledger/data/data_reset_repository_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pipeline_providers.g.dart';

// Phase 1 pipeline wiring: SMS -> parser_core -> ledger, onboarding stores.

/// Native `sms` channel.
@Riverpod(keepAlive: true)
SmsChannel smsChannel(Ref ref) => const SmsChannel();

/// Native `permissions` channel.
@Riverpod(keepAlive: true)
PermissionsChannel permissionsChannel(Ref ref) => const PermissionsChannel();

/// String store over the settings table.
@Riverpod(keepAlive: true)
KeyValueStore keyValueStore(Ref ref) =>
    SettingsKeyValueStore(ref.watch(settingsRepositoryProvider));

/// Keystore-backed store; override in tests.
@Riverpod(keepAlive: true)
SecureStore secureStore(Ref ref) => const SecureStoreImpl();

/// Sealed statement identity (F-01).
@Riverpod(keepAlive: true)
IdentityRepository identityRepository(Ref ref) =>
    IdentityStore(ref.watch(secureStoreProvider));

/// Plain profile (F-01).
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    ProfileStore(ref.watch(keyValueStoreProvider));

/// SMS permission state machine over the native channel.
@Riverpod(keepAlive: true)
SmsPermissionRepository smsPermissionRepository(Ref ref) =>
    SmsPermissionRepositoryImpl(
      ref.watch(permissionsChannelProvider),
      lockSkipper: ref.watch(lockSkipperProvider),
    );

/// POST_NOTIFICATIONS request.
@Riverpod(keepAlive: true)
NotificationPermission notificationPermission(Ref ref) =>
    NotificationPermissionImpl(
      ref.watch(permissionsChannelProvider),
      lockSkipper: ref.watch(lockSkipperProvider),
    );

/// Persisted SMS settings (F-02).
@Riverpod(keepAlive: true)
SmsSettingsRepository smsSettingsRepository(Ref ref) =>
    SmsSettingsStore(ref.watch(keyValueStoreProvider));

/// Inbox reader.
@Riverpod(keepAlive: true)
SmsInboxSource smsInboxSource(Ref ref) => SmsInboxSourceImpl(
      ref.watch(smsChannelProvider),
      senderPattern: SmsEngine.senderPatternDefault,
    );

/// Live receiver bridge.
@Riverpod(keepAlive: true)
SmsLiveSource smsLiveSource(Ref ref) =>
    SmsLiveSourceImpl(ref.watch(smsChannelProvider));

/// Ledger wipe for Settings.
@Riverpod(keepAlive: true)
DataResetRepository dataResetRepository(Ref ref) =>
    DataResetRepositoryImpl(ref.watch(appDatabaseProvider));

/// Last four digits of the user's own numbers (FR-01-08).
Future<Set<String>> _ownTails(Ref ref) async {
  final p = await ref.read(profileRepositoryProvider).read();
  final id = await ref.read(identityRepositoryProvider).read();
  return ownNumberTails([p.phone, id?.phone, id?.altPhone]);
}

/// Parse and store one message (F-02 -> F-06 -> F-08).
@Riverpod(keepAlive: true)
IngestMessage ingestMessage(Ref ref) => IngestMessage(
      ledger: ref.watch(transactionRepositoryProvider),
      ownNumberTails: () => _ownTails(ref),
      cardDues: ref.watch(cardDueRepositoryProvider),
      holdings: ref.watch(holdingRepositoryProvider),
      accounts: ref.watch(applyStatementAccountsProvider),
      senderOverrides: ref.watch(senderOverridesCacheProvider),
    );

/// Builds a ScanSms; onProgress feeds the Settings progress line.
@Riverpod(keepAlive: true)
ScanSms Function(void Function(SmsScanProgress)? onProgress) scanSmsFactory(
  Ref ref,
) {
  final ingest = ref.watch(ingestMessageProvider);
  final inbox = ref.watch(smsInboxSourceProvider);
  final settings = ref.watch(smsSettingsRepositoryProvider);
  final activity = ref.watch(activityLoggerProvider);
  return (onProgress) => ScanSms(
        activity: activity,
        inbox: inbox,
        settings: settings,
        accept: ingest.accepts,
        prepare: ingest.prepare,
        ingest: ingest.call,
        ingestBatch: (batch) async => [
          for (final d in await ingest.ingestBatch(batch)) d.outcome,
        ],
        onProgress: onProgress,
        log: ref.watch(appLoggerProvider),
      );
}

/// Live SMS lifecycle.
@Riverpod(keepAlive: true)
SmsEngine smsEngine(Ref ref) {
  final ingest = ref.watch(ingestMessageProvider);
  final settings = ref.watch(smsSettingsRepositoryProvider);
  final scan = ref.watch(scanSmsFactoryProvider);
  final engine = SmsEngine(
    live: ref.watch(smsLiveSourceProvider),
    settings: settings,
    handle: HandleLiveSms(
      settings: settings,
      accept: ingest.accepts,
      ingest: ingest.call,
      activity: ref.watch(activityLoggerProvider),
    ),
    scan: () => scan(null),
    prepare: ingest.prepare,
    senderPattern: SmsEngine.senderPatternDefault,
    scheduler: SmsScanSchedulerImpl(
      const BackgroundChannel(),
      onPlanned: (next) =>
          recordNextSync(ref.read(settingsRepositoryProvider), next),
    ),
  );
  ref.onDispose(engine.stop);
  return engine;
}

/// Starts the engine when permission is (or becomes) granted; one full scan
/// on each missing-to-granted change (FR-01-09, FR-01-12).
@Riverpod(keepAlive: true)
SmsPermissionWatcher smsPermissionWatcher(Ref ref) {
  final engine = ref.watch(smsEngineProvider);
  final scan = ref.watch(scanSmsFactoryProvider);
  return SmsPermissionWatcher(
    repository: ref.watch(smsPermissionRepositoryProvider),
    onGranted: () async {
      // Fire and forget: the scan reports through the ledger streams.
      unawaited(() async {
        await engine.start();
        await scan(null)(const SmsScanRequest.full());
      }());
    },
  );
}

/// Re-reads SMS access and starts or drains the engine. Call at launch and on
/// every app resume (FR-01-09, FR-02-06). Never throws.
@Riverpod(keepAlive: true)
Future<void> Function() pipelineSync(Ref ref) => () async {
      unawaited(ref.read(notificationSyncProvider)());
      try {
        final s = await ref.read(smsPermissionWatcherProvider).refresh();
        if (!s.granted) return;
        final engine = ref.read(smsEngineProvider);
        if (engine.running) {
          await engine.drain();
        } else {
          await engine.start();
        }
        // After ingest: alert checks (FR-21-13); never throws.
        unawaited(ref.read(alertsEngineProvider).run());
      } on Object {
        // Native side missing (tests, desktop).
      }
    };

/// Whether Welcome must show; null while loading (FR-01-01).
@Riverpod(keepAlive: true)
class OnboardingGate extends _$OnboardingGate {
  static const _skipKey = 'onboarding_skipped';

  @override
  Future<bool> build() async {
    final p = await ref.read(profileRepositoryProvider).read();
    final skipped =
        await ref.read(keyValueStoreProvider).getString(_skipKey) == 'true';
    if (skipped) return false;
    return onboardingNeeded(
      name: p.name,
      email: p.email,
      phone: p.phone,
      mailConnected: false,
    );
  }

  /// Marks setup skipped; the user can still fill it in later.
  Future<void> skip() async {
    await ref.read(keyValueStoreProvider).setString(_skipKey, 'true');
    ref.invalidateSelf();
  }

  /// Re-evaluates after the profile was saved.
  void refresh() => ref.invalidateSelf();
}

/// Ending onboarding: sealed identity first, then profile (FR-01-06).
@Riverpod(keepAlive: true)
FinishOnboarding finishOnboarding(Ref ref) => FinishOnboarding(
      identity: ref.watch(identityRepositoryProvider),
      profile: ref.watch(profileRepositoryProvider),
    );

/// Ask-once notification prompt (FR-01-14).
@Riverpod(keepAlive: true)
AskNotificationsOnce askNotificationsOnce(Ref ref) => AskNotificationsOnce(
      ref.watch(keyValueStoreProvider),
      ref.watch(notificationPermissionProvider),
    );

/// SMS access as the UI sees it (FR-01-09..11); re-read on every resume.
@Riverpod(keepAlive: true)
class SmsPermission extends _$SmsPermission {
  @override
  Future<SmsPermissionState> build() => _read();

  Future<SmsPermissionState> _read() async {
    try {
      return await ref.read(smsPermissionWatcherProvider).refresh();
    } on Object {
      return const SmsPermissionState();
    }
  }

  /// Re-reads the real state.
  Future<void> refresh() async => state = AsyncData(await _read());

  /// Asks, or opens App settings when blocked.
  Future<void> request() async {
    try {
      state = AsyncData(await ref.read(smsPermissionWatcherProvider).request());
    } on Object {
      state = const AsyncData(SmsPermissionState());
    }
  }

  /// Opens App info.
  Future<void> openAppSettings() async {
    try {
      await ref.read(smsPermissionRepositoryProvider).openAppSettings();
    } on Object {
      // No native side.
    }
  }

  /// Hides the Home card for good (FR-01-11).
  Future<void> dismissPrompt() => ref
      .read(smsSettingsRepositoryProvider)
      .setPromptDismissed(dismissed: true);
}

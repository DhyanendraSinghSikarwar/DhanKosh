import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/nightly_schedule.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/drain_pending_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/handle_live_sms.dart';

/// Days re-read by the nightly scan (FR-02-14).
const nightlyScanDays = 14;

/// Runs [body] against a fresh container (own encrypted DB connection, key
/// from secure storage) and closes the database afterwards.
Future<bool> _withContainer(
  Future<bool> Function(ProviderContainer c) body, {
  ProviderContainer Function()? create,
}) async {
  final c = (create ?? ProviderContainer.new)();
  try {
    return await body(c);
  } finally {
    try {
      await c.read(appDatabaseProvider).close();
    } on Object {
      // Never opened.
    }
    c.dispose();
  }
}

/// Live SMS while the app is closed: drain the native queue and ingest through
/// the same pipeline as the foreground (FR-02-01, AC-02-01).
Future<bool> smsDrainTask({ProviderContainer Function()? create}) =>
    _withContainer(
      (c) async {
        final ingest = c.read(ingestMessageProvider);
        await ingest.prepare();
        await DrainPendingSms(
          live: c.read(smsLiveSourceProvider),
          handle: HandleLiveSms(
            settings: c.read(smsSettingsRepositoryProvider),
            accept: ingest.accepts,
            ingest: ingest.call,
            activity: c.read(activityLoggerProvider),
          ),
        )();
        return true;
      },
      create: create,
    );

/// Nightly catch-up: re-read the last 14 days of SMS (skipped while SMS
/// reading is paused, FR-02-14, FR-02-05), then sync email (FR-03-17; a no-op
/// without a connected account). Retry only on retryable errors.
Future<bool> smsNightlyTask({ProviderContainer Function()? create}) =>
    _withContainer(
      (c) async {
        var ok = true;
        final settings = await c.read(smsSettingsRepositoryProvider).read();
        if (settings.enabled) {
          final r = await c.read(scanSmsFactoryProvider)(null)(
            const SmsScanRequest.recent(nightlyScanDays),
          );
          // No permission is not retryable; other errors are.
          ok = r.error == null || r.error == 'permission';
        }
        final email = await c.read(emailSyncRunnerProvider).run();
        // Daily alert check (FR-21-13); never throws.
        await c.read(alertsEngineProvider).run();
        // The periodic job fires again at the next 02:30 (FR-22-08).
        final planned = DateTime.now().add(nextNightlyDelay(DateTime.now()));
        try {
          await recordNextSync(c.read(settingsRepositoryProvider), planned);
        } on Object {
          // Display only.
        }
        return ok && !email.retryable;
      },
      create: create,
    );

/// Alert check on its own (FR-21-13): budgets, bills, renewals.
Future<bool> alertsCheckTask({ProviderContainer Function()? create}) =>
    _withContainer(
      (c) async {
        await c.read(alertsEngineProvider).run();
        return true;
      },
      create: create,
    );

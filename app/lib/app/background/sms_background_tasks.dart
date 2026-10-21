import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
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
        await DrainPendingSms(
          live: c.read(smsLiveSourceProvider),
          handle: HandleLiveSms(
            settings: c.read(smsSettingsRepositoryProvider),
            accept: ingest.accepts,
            ingest: ingest.call,
          ),
        )();
        return true;
      },
      create: create,
    );

/// Nightly catch-up: re-read the last 14 days; skipped while SMS reading is
/// paused (FR-02-14, FR-02-05).
Future<bool> smsNightlyTask({ProviderContainer Function()? create}) =>
    _withContainer(
      (c) async {
        final settings = await c.read(smsSettingsRepositoryProvider).read();
        if (!settings.enabled) return true;
        final r = await c.read(scanSmsFactoryProvider)(null)(
          const SmsScanRequest.recent(nightlyScanDays),
        );
        // No permission is not retryable; other errors are.
        return r.error == null || r.error == 'permission';
      },
      create: create,
    );

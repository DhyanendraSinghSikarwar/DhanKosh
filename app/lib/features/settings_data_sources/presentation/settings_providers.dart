import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/settings_data_sources/domain/sample_data.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_providers.g.dart';

/// Live SMS reading on or off (FR-02-05).
@riverpod
Stream<bool> smsEnabled(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(SettingKeys.smsEnabled);

/// Amount masking (FR-26-29).
@riverpod
Stream<bool> hideAmounts(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(SettingKeys.hideAmounts);

/// Developer section flag (FR-26-27).
@riverpod
Stream<bool> developerTools(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(SettingKeys.developerTools);

/// Last scan time (epoch ms, 0 = never).
@riverpod
Stream<int> lastScanAt(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(SettingKeys.lastSmsScan);

/// Last scan summary text.
@riverpod
Stream<String> lastScanResult(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watch(SettingKeys.lastSmsResult);

/// State of the "Scan now" action (FR-02-15, FR-02-11).
class ScanUiState {
  /// Creates a state.
  const ScanUiState({this.running = false, this.progress, this.message});

  /// A scan is in flight.
  final bool running;

  /// Live counts while running.
  final SmsScanProgress? progress;

  /// Result summary or error line of the last run.
  final String? message;
}

/// Runs the manual inbox scan and exposes its progress.
@riverpod
class ScanController extends _$ScanController {
  @override
  ScanUiState build() => const ScanUiState();

  /// Full look-back scan.
  Future<void> scanNow() async {
    if (state.running) return;
    state = const ScanUiState(running: true);
    final scan = ref.read(scanSmsFactoryProvider)(
      (p) => state = ScanUiState(running: true, progress: p),
    );
    final r = await scan(const SmsScanRequest.full());
    state = ScanUiState(
      message: r.error == 'permission'
          ? 'SMS access is off. Allow it first.'
          : r.error != null
              ? 'Scan failed (${r.error}).'
              : r.summary,
    );
  }
}

/// One-shot actions: sample data and clear (FR-26-27, FR-26-28).
@riverpod
class DeveloperActions extends _$DeveloperActions {
  @override
  String? build() => null;

  /// Ingests [SampleData] through the normal path; returns a status line.
  Future<void> addSampleData() async {
    final ingest = ref.read(ingestMessageProvider);
    var added = 0;
    var other = 0;
    for (final m in SampleData.build(DateTime.now())) {
      final d = await ingest.detail(m);
      if (d.outcome == IngestOutcome.inserted) {
        added++;
      } else {
        other++;
      }
    }
    state = 'Added $added sample transactions'
        '${other > 0 ? ' ($other already there)' : ''}.';
  }

  /// Wipes the ledger and resets the scan cursor.
  Future<void> clearAll() async {
    await ref.read(dataResetRepositoryProvider).clearLedger();
    state = 'All data cleared.';
  }
}

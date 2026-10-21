import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';

/// [SmsSettingsRepository] over a [KeyValueStore] (section 9 keys).
class SmsSettingsStore implements SmsSettingsRepository {
  /// Creates the store.
  const SmsSettingsStore(this._kv);

  final KeyValueStore _kv;

  static const _enabled = 'sms_enabled';
  static const _cursor = 'sms_cursor';
  static const _lastScan = 'last_sms_scan';
  static const _lastResult = 'last_sms_result';
  static const _dismissed = 'sms_prompt_dismissed';
  static const _lookback = 'lookback_days';
  static const _allowedLookback = {7, 30, 90, 180, 365};

  @override
  Future<SmsSettings> read() async {
    final lookback = int.tryParse(await _kv.getString(_lookback) ?? '');
    return SmsSettings(
      enabled: (await _kv.getString(_enabled)) != 'false',
      cursor: int.tryParse(await _kv.getString(_cursor) ?? '') ?? 0,
      lastScanAt: int.tryParse(await _kv.getString(_lastScan) ?? ''),
      lastResult: await _kv.getString(_lastResult),
      promptDismissed: (await _kv.getString(_dismissed)) == 'true',
      lookbackDays: _allowedLookback.contains(lookback) ? lookback! : 90,
    );
  }

  @override
  Future<void> setEnabled({required bool enabled}) =>
      _kv.setString(_enabled, '$enabled');

  @override
  Future<void> saveScan({
    required int cursor,
    required int lastScanAt,
    required String lastResult,
  }) async {
    final old = int.tryParse(await _kv.getString(_cursor) ?? '') ?? 0;
    if (cursor > old) await _kv.setString(_cursor, '$cursor');
    await _kv.setString(_lastScan, '$lastScanAt');
    await _kv.setString(_lastResult, lastResult);
  }

  @override
  Future<void> setPromptDismissed({required bool dismissed}) =>
      _kv.setString(_dismissed, '$dismissed');

  @override
  Future<void> setLookbackDays(int days) async {
    if (_allowedLookback.contains(days)) {
      await _kv.setString(_lookback, '$days');
    }
  }
}

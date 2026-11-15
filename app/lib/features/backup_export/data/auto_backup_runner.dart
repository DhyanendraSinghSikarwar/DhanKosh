import 'package:hisaab/features/backup_export/data/scheduled_backup_service.dart';
import 'package:hisaab/features/backup_export/domain/scheduled_backup.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// Runs the automatic backup from the stored settings (FR-24-34..34): the
/// phone copy always, the cloud copy only when the user allowed it.
class AutoBackupRunner {
  /// Creates the runner. [phoneSink] is the app's own folder; [treeSink]
  /// builds a sink for a picked folder (its id and tree address).
  AutoBackupRunner({
    required ScheduledBackupService service,
    required SettingsRepository settings,
    required SecureStore secure,
    required BackupSink phoneSink,
    required BackupSink Function(String id, String uri) treeSink,
    DateTime Function()? clock,
    this.minGap = const Duration(minutes: 10),
  })  : _service = service,
        _settings = settings,
        _secure = secure,
        _phone = phoneSink,
        _tree = treeSink,
        _clock = clock ?? DateTime.now;

  final ScheduledBackupService _service;
  final SettingsRepository _settings;
  final SecureStore _secure;
  final BackupSink _phone;
  final BackupSink Function(String id, String uri) _tree;
  final DateTime Function() _clock;

  /// Shortest time between two automatic runs (not applied to a forced run).
  final Duration minGap;

  Future<void>? _running;

  /// Runs when automatic backup is on and a passphrase is saved. Null when it
  /// did not run. [force] skips the minimum gap ("Back up now").
  Future<BackupRunResult?> run({bool force = false}) {
    final active = _running;
    if (active != null) return active.then((_) => null);
    final f = _run(force: force);
    _running = f.then((_) {}, onError: (Object _) {}).whenComplete(() {
      _running = null;
    });
    return f;
  }

  Future<BackupRunResult?> _run({required bool force}) async {
    if (!await _settings.read(autoBackupKey)) return null;
    final pass = await _secure.read(autoBackupPassphraseSecret);
    if (pass == null || pass.isEmpty) return null;
    final now = _clock();
    final last = await _settings.read(autoBackupLastKey);
    if (!force &&
        last > 0 &&
        now.millisecondsSinceEpoch - last < minGap.inMilliseconds) {
      return null;
    }
    final sinks = <String, BackupSink>{};
    final localUri = await _settings.read(autoBackupLocalKey);
    sinks['phone'] = localUri.isEmpty ? _phone : _tree('phone', localUri);
    if (await _settings.read(autoBackupDriveKey)) {
      final uri = await _settings.read(autoBackupDriveUriKey);
      if (uri.isNotEmpty) sinks['cloud'] = _tree('cloud', uri);
    }
    final r = await _service.run(
      passphrase: pass,
      sinks: sinks,
      manifest: await _settings.read(autoBackupManifestKey),
      now: now,
    );
    await _settings.write(autoBackupManifestKey, r.manifest);
    await _settings.write(autoBackupLastKey, now.millisecondsSinceEpoch);
    await _settings.write(
      autoBackupResultKey,
      r.result.ok
          ? 'ok'
          : r.result.failed.contains('phone')
              ? 'phone_failed'
              : 'cloud_failed',
    );
    return r.result;
  }
}

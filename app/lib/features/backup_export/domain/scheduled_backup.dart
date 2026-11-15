import 'dart:typed_data';

import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// Automatic backup on or off (FR-24-34). Off by default.
const autoBackupKey = SettingKey<bool>('auto_backup', false);

/// Folder chosen for the phone copy (system tree address); empty keeps the
/// copy in the app's own storage (FR-24-35).
const autoBackupLocalKey = SettingKey<String>('auto_backup_local', '');

/// Name shown for the chosen phone folder.
const autoBackupLocalNameKey = SettingKey<String>('auto_backup_local_name', '');

/// Second copy in a cloud folder (Google Drive) on or off (FR-24-36). Off by
/// default: only the phone copy is made until the user allows it.
const autoBackupDriveKey = SettingKey<bool>('auto_backup_drive', false);

/// Folder chosen for the cloud copy (system tree address).
const autoBackupDriveUriKey = SettingKey<String>('auto_backup_drive_uri', '');

/// Cloud folder and account name shown to the user.
const autoBackupDriveNameKey = SettingKey<String>('auto_backup_drive_name', '');

/// Epoch ms of the last run that wrote or checked every copy; 0 when never.
const autoBackupLastKey = SettingKey<int>('auto_backup_last', 0);

/// Short result of the last run: `ok`, `phone_failed`, `cloud_failed`.
const autoBackupResultKey = SettingKey<String>('auto_backup_result', '');

/// Hashes of the parts each copy holds, per sink (JSON), so only changed
/// months are written again (FR-24-37).
const autoBackupManifestKey = SettingKey<String>('auto_backup_manifest', '{}');

/// Secure-store key of the passphrase the unattended backup encrypts with.
const autoBackupPassphraseSecret = 'auto_backup_passphrase';

/// A place a backup copy is written: the app's own storage, or a folder the
/// user picked on the phone or in a cloud provider.
abstract interface class BackupSink {
  /// Stable id (`phone`, `cloud`).
  String get id;

  /// File names already there.
  Future<Set<String>> list();

  /// Writes [bytes] as [name], replacing a file of that name.
  Future<void> write(String name, Uint8List bytes);
}

/// One run's outcome per sink.
class BackupRunResult {
  /// Creates a result.
  const BackupRunResult(this.written, this.failed);

  /// Files written per sink id.
  final Map<String, int> written;

  /// Sink ids that failed.
  final Set<String> failed;

  /// True when nothing failed.
  bool get ok => failed.isEmpty;
}

/// The parts of a backup (FR-24-37): the base file holds everything but the
/// transactions, and each month holds that month's transactions, so one month
/// can be opened without reading the rest.
abstract final class BackupParts {
  /// Name of the base part.
  static const base = 'dhankosh-base.dkbk';

  /// `dhankosh-2026-10.dkbk`.
  static String monthName(String month) => 'dhankosh-$month.dkbk';

  /// `2026-10` of [epochMs] in the phone's time zone.
  static String monthOf(int epochMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}';
  }

  /// Splits [doc] into named parts: the base without transactions, and one
  /// part per month that has transactions. Every part keeps the format
  /// header, so each opens and restores like a full backup.
  static Map<String, Map<String, Object?>> split(Map<String, Object?> doc) {
    final txs = [
      for (final t in (doc['transactions'] as List?) ?? const <Object?>[])
        (t! as Map).cast<String, Object?>(),
    ];
    final byMonth = <String, List<Map<String, Object?>>>{};
    for (final t in txs) {
      final ts = t['ts'];
      if (ts is! int) continue;
      (byMonth[monthOf(ts)] ??= []).add(t);
    }
    final empty = {
      for (final k in ['format', 'schema', 'createdAt']) k: doc[k],
    };
    return {
      base: {...doc, 'transactions': const <Object?>[]},
      for (final e
          in (byMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
        monthName(e.key): {...empty, 'transactions': e.value},
    };
  }
}

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:hisaab/features/backup_export/data/backup_crypto.dart';
import 'package:hisaab/features/backup_export/data/backup_data.dart';
import 'package:hisaab/features/backup_export/domain/backup_errors.dart';
import 'package:hisaab/features/backup_export/domain/blob_gateway.dart';
import 'package:hisaab/features/backup_export/domain/full_backup.dart';
import 'package:hisaab/features/backup_export/domain/passphrase_strength.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// Epoch ms of the last encrypted backup; 0 when never.
const lastFullBackupKey = SettingKey<int>('last_full_backup', 0);

/// Encrypted full backup and restore (FR-24-17..27).
class FullBackupService implements FullBackupPort {
  /// Creates the service. [iterations] is lowered only by tests.
  const FullBackupService(
    this._data,
    this._write, {
    this.iterations = BackupCrypto.defaultIterations,
  });

  final BackupData _data;
  final Future<void> Function(int nowMs) _write;

  /// PBKDF2 iterations used when writing.
  final int iterations;

  /// File name suggestion, e.g. `dhankosh-backup-2026-10-26.dkbk`.
  static String fileName(DateTime now) =>
      'dhankosh-backup-${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}.dkbk';

  /// The encrypted file bytes (FR-24-17).
  Future<Uint8List> build(String passphrase, {required DateTime now}) async {
    if (passphrase.length < PassphraseStrength.minLength) {
      throw const FormatException('Passphrase needs 8 or more characters');
    }
    final doc = await _data.collect(now: now.millisecondsSinceEpoch);
    final json = await Isolate.run(() => jsonEncode(doc));
    return await BackupCrypto.encrypt(json, passphrase, iterations: iterations);
  }

  @override

  /// Builds and saves; null when the picker is cancelled.
  Future<({String file, BackupCounts counts})?> export(
    BlobGateway gateway,
    String passphrase, {
    required DateTime now,
  }) async {
    final bytes = await build(passphrase, now: now);
    final saved = await gateway.saveFile(
      fileName(now),
      bytes,
      'application/octet-stream',
    );
    if (saved == null) return null;
    await _write(now.millisecondsSinceEpoch);
    final doc = await _data.collect(now: now.millisecondsSinceEpoch);
    return (file: saved, counts: BackupData.summarize(doc));
  }

  @override

  /// Decrypts and checks [file]; nothing is written (FR-24-20, FR-24-23).
  Future<OpenedBackup> open(Uint8List file, String passphrase) async {
    final json = await BackupCrypto.decrypt(file, passphrase);
    final Map<String, Object?> doc;
    try {
      doc = await Isolate.run(
        () => (jsonDecode(json) as Map).cast<String, Object?>(),
      );
    } on Object {
      throw const BackupFormatException('Backup content is unreadable');
    }
    try {
      BackupData.validate(doc);
    } on FormatException catch (e) {
      throw BackupFormatException(e.message);
    }
    return OpenedBackup(
      doc,
      BackupData.summarize(doc),
      (doc['createdAt'] as int?) ?? 0,
    );
  }

  @override

  /// Restores an opened backup (FR-24-25..27).
  Future<BackupCounts> restore(OpenedBackup b, {bool replace = false}) =>
      _data.restore(b.doc, replace: replace);
}

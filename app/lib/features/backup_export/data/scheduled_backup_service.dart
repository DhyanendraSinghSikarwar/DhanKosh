import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:hisaab/features/backup_export/data/backup_crypto.dart';
import 'package:hisaab/features/backup_export/data/backup_data.dart';
import 'package:hisaab/features/backup_export/domain/passphrase_strength.dart';
import 'package:hisaab/features/backup_export/domain/scheduled_backup.dart';

/// Keeps month-wise encrypted backups in one or two folders (FR-24-34..34).
///
/// The base part and every month are separate files. A run writes only the
/// parts whose content changed since that folder last received them (or whose
/// file is gone), so a sync that touches one month rewrites one file.
class ScheduledBackupService {
  /// Creates the service. [iterations] is lowered only by tests.
  const ScheduledBackupService(
    this._data, {
    this.iterations = BackupCrypto.defaultIterations,
  });

  final BackupData _data;

  /// PBKDF2 iterations used when writing.
  final int iterations;

  /// Makes every sink current. [manifest] is the stored JSON of what each sink
  /// holds; the updated JSON is returned with the result.
  Future<({BackupRunResult result, String manifest})> run({
    required String passphrase,
    required Map<String, BackupSink> sinks,
    required String manifest,
    required DateTime now,
  }) async {
    if (passphrase.length < PassphraseStrength.minLength) {
      throw const FormatException('Passphrase needs 8 or more characters');
    }
    final doc = await _data.collect(now: now.millisecondsSinceEpoch);
    final parts = BackupParts.split(doc);
    final hashes = await Isolate.run(
      () => {
        for (final e in parts.entries) e.key: _hash(e.value),
      },
    );
    final stored = _readManifest(manifest);
    final written = <String, int>{};
    final failed = <String>{};
    final cache = <String, List<int>>{};
    for (final sink in sinks.entries) {
      var n = 0;
      try {
        final present = await sink.value.list();
        final mine = {...?stored[sink.key]};
        for (final p in parts.entries) {
          final same = mine[p.key] == hashes[p.key] && present.contains(p.key);
          if (same) continue;
          final bytes = cache[p.key] ??= await _encrypt(p.value, passphrase);
          await sink.value.write(p.key, Uint8List.fromList(bytes));
          mine[p.key] = hashes[p.key]!;
          n++;
        }
        stored[sink.key] = mine;
      } on Object {
        failed.add(sink.key);
      }
      written[sink.key] = n;
    }
    return (
      result: BackupRunResult(written, failed),
      manifest: jsonEncode(stored),
    );
  }

  Future<List<int>> _encrypt(
    Map<String, Object?> part,
    String passphrase,
  ) async {
    final json = await Isolate.run(() => jsonEncode(part));
    return await BackupCrypto.encrypt(json, passphrase, iterations: iterations);
  }

  static String _hash(Map<String, Object?> part) {
    final copy = {...part}..remove('createdAt');
    return sha256.convert(utf8.encode(jsonEncode(copy))).toString();
  }

  static Map<String, Map<String, String>> _readManifest(String json) {
    try {
      final m = (jsonDecode(json) as Map).cast<String, Object?>();
      return {
        for (final e in m.entries)
          e.key: {
            for (final f in (e.value! as Map).entries)
              f.key as String: f.value! as String,
          },
      };
    } on Object {
      return {};
    }
  }
}

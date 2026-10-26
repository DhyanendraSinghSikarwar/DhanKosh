import 'dart:typed_data';

import 'package:hisaab/features/backup_export/domain/blob_gateway.dart';

/// What a backup holds, or what a restore added (FR-24-23, FR-24-26).
class BackupCounts {
  /// Creates counts.
  const BackupCounts(this.counts);

  /// Label to count, in display order.
  final Map<String, int> counts;

  /// Sum of all counts.
  int get total => counts.values.fold(0, (a, b) => a + b);

  /// "12 transactions, 3 accounts".
  String get text => counts.entries
      .where((e) => e.value > 0)
      .map((e) => '${e.value} ${e.key}')
      .join(', ');
}

/// A decrypted backup waiting for the user's confirmation (FR-24-23).
class OpenedBackup {
  /// Creates the holder.
  const OpenedBackup(this.doc, this.counts, this.createdAt);

  /// The decoded document.
  final Map<String, Object?> doc;

  /// What it contains.
  final BackupCounts counts;

  /// When it was made, epoch ms.
  final int createdAt;
}

/// Encrypted full backup and restore (FR-24-17..27).
abstract interface class FullBackupPort {
  /// Builds and saves the backup; null when the picker is cancelled.
  Future<({String file, BackupCounts counts})?> export(
    BlobGateway gateway,
    String passphrase, {
    required DateTime now,
  });

  /// Decrypts and checks [file]; nothing is written.
  Future<OpenedBackup> open(Uint8List file, String passphrase);

  /// Restores an opened backup; [replace] erases existing data first.
  Future<BackupCounts> restore(OpenedBackup b, {bool replace = false});
}

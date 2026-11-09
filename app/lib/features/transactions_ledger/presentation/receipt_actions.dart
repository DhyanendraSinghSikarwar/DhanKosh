import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Receipt photos (FR-08-31): one per transaction, kept on the phone in the
/// app's own `receipts` folder, resized to at most 1920 px.
abstract final class ReceiptActions {
  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/receipts');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  /// The file of [fileName], or null when it is gone.
  static Future<File?> fileOf(String? fileName) async {
    if (fileName == null) return null;
    final f = File('${(await _dir()).path}/$fileName');
    return f.existsSync() ? f : null;
  }

  /// Deletes the photo file of [fileName]; never throws.
  static Future<void> deleteFile(String? fileName) async {
    try {
      await (await fileOf(fileName))?.delete();
    } on Object {
      // A leftover file is harmless.
    }
  }

  /// Camera or gallery, then attach the photo to [tx] (replacing one).
  static Future<void> pickAndAttach(
    BuildContext context,
    WidgetRef ref,
    LedgerTx tx,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('receipt_camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t('Take a photo')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              key: const Key('receipt_gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t('Choose from gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;
    final name = '${tx.id}-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy('${(await _dir()).path}/$name');
    await deleteFile(tx.receipt);
    await ref.read(transactionRepositoryProvider).setReceipt(tx.id, name);
  }

  /// Full-screen view with Replace and Remove.
  static Future<void> view(
    BuildContext context,
    WidgetRef ref,
    LedgerTx tx,
  ) async {
    final file = await fileOf(tx.receipt);
    if (!context.mounted) return;
    if (file == null) {
      await pickAndAttach(context, ref, tx);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(child: Image.file(file)),
            ),
            OverflowBar(
              children: [
                TextButton(
                  key: const Key('receipt_replace'),
                  onPressed: () => Navigator.pop(ctx, 'replace'),
                  child: Text(t('Replace')),
                ),
                TextButton(
                  key: const Key('receipt_remove'),
                  onPressed: () => Navigator.pop(ctx, 'remove'),
                  child: Text(t('Remove')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t('Close')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'remove') {
      await deleteFile(tx.receipt);
      await ref.read(transactionRepositoryProvider).setReceipt(tx.id, null);
    } else if (action == 'replace') {
      await pickAndAttach(context, ref, tx);
    }
  }
}

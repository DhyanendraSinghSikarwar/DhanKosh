import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/backup_providers.dart';
import 'package:hisaab/features/backup_export/domain/backup_errors.dart';
import 'package:hisaab/features/backup_export/domain/blob_gateway.dart';
import 'package:hisaab/features/backup_export/domain/full_backup.dart';
import 'package:hisaab/features/backup_export/presentation/backup_export_screen.dart';

class _Blob implements BlobGateway {
  _Blob(this.pick);
  Uint8List? pick;
  String? savedName;
  @override
  Future<String?> saveFile(String name, List<int> bytes, String mime) async {
    savedName = name;
    return name;
  }

  @override
  Future<Uint8List?> pickBytes() async => pick;
}

class _Port implements FullBackupPort {
  String? exportedWith;
  String? openedWith;
  bool? replaced;
  bool wrong = false;

  @override
  Future<({String file, BackupCounts counts})?> export(
    BlobGateway gateway,
    String passphrase, {
    required DateTime now,
  }) async {
    exportedWith = passphrase;
    final f = await gateway.saveFile('x.dkbk', [1], 'application/octet-stream');
    return (file: f!, counts: const BackupCounts({'transactions': 2}));
  }

  @override
  Future<OpenedBackup> open(Uint8List file, String passphrase) async {
    openedWith = passphrase;
    if (wrong) throw const BackupAuthException();
    return const OpenedBackup(
      {},
      BackupCounts({'transactions': 12, 'accounts': 3}),
      1790000000000,
    );
  }

  @override
  Future<BackupCounts> restore(OpenedBackup b, {bool replace = false}) async {
    replaced = replace;
    return const BackupCounts({'transactions': 12});
  }
}

void main() {
  late _Port port;
  late _Blob blob;

  Future<void> pump(WidgetTester t) async {
    port = _Port();
    blob = _Blob(Uint8List.fromList([1, 2, 3]));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          fullBackupServiceProvider.overrideWithValue(port),
          blobGatewayProvider.overrideWithValue(blob),
          lastExportProvider.overrideWith((ref) async => 0),
          lastFullBackupProvider.overrideWith((ref) async => 0),
        ],
        child: const MaterialApp(home: BackupExportScreen()),
      ),
    );
    await t.pumpAndSettle();
  }

  // FR-24-22, FR-24-24
  testWidgets('export asks twice, warns, hints strength', (t) async {
    await pump(t);
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('full-backup-export')),
        matching: find.text('Export'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('backup-warning')), findsOneWidget);
    expect(find.textContaining('cannot recover'), findsOneWidget);
    TextButton ok() =>
        t.widget<TextButton>(find.byKey(const Key('backup-pass-ok')));
    expect(ok().onPressed, isNull);

    await t.enterText(find.byKey(const Key('backup-pass')), 'short');
    await t.pump();
    expect(find.text('Use at least 8 characters'), findsOneWidget);

    await t.enterText(find.byKey(const Key('backup-pass')), 'Blue-Tiger-42-x');
    await t.pump();
    expect(find.byKey(const Key('backup-strength')), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    await t.enterText(find.byKey(const Key('backup-pass2')), 'different');
    await t.pump();
    expect(find.text('Passphrases differ'), findsOneWidget);
    expect(ok().onPressed, isNull);

    await t.enterText(find.byKey(const Key('backup-pass2')), 'Blue-Tiger-42-x');
    await t.pump();
    expect(ok().onPressed, isNotNull);
    await t.tap(find.byKey(const Key('backup-pass-ok')));
    await t.pumpAndSettle();
    expect(port.exportedWith, 'Blue-Tiger-42-x');
    expect(blob.savedName, 'x.dkbk');
    expect(find.textContaining('Backup saved'), findsOneWidget);
  });

  // FR-24-23, FR-24-26
  testWidgets('restore: summary, merge by default', (t) async {
    await pump(t);
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('full-backup-restore')),
        matching: find.text('Restore'),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('restore-pass')), 'pass-phrase');
    await t.tap(find.byKey(const Key('restore-pass-ok')));
    await t.pumpAndSettle();
    expect(port.openedWith, 'pass-phrase');
    expect(
      find.textContaining('12 transactions, 3 accounts'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('restore-merge')));
    await t.pumpAndSettle();
    expect(port.replaced, isFalse);
    expect(find.textContaining('Restored 12 transactions'), findsOneWidget);
  });

  // FR-24-27
  testWidgets('replace everything needs a second confirm', (t) async {
    await pump(t);
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('full-backup-restore')),
        matching: find.text('Restore'),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('restore-pass')), 'pass-phrase');
    await t.tap(find.byKey(const Key('restore-pass-ok')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('restore-replace')));
    await t.pumpAndSettle();
    expect(port.replaced, isNull);
    expect(find.text('Erase and replace?'), findsOneWidget);
    await t.tap(find.byKey(const Key('restore-replace-confirm')));
    await t.pumpAndSettle();
    expect(port.replaced, isTrue);
  });

  // FR-24-20
  testWidgets('wrong passphrase shows a clear error, restores nothing',
      (t) async {
    await pump(t);
    port.wrong = true;
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('full-backup-restore')),
        matching: find.text('Restore'),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('restore-pass')), 'nope-nope');
    await t.tap(find.byKey(const Key('restore-pass-ok')));
    await t.pumpAndSettle();
    expect(find.text(BackupAuthException.text), findsOneWidget);
    expect(port.replaced, isNull);
  });
}

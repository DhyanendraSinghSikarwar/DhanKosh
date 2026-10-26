import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/backup_providers.dart';
import 'package:hisaab/features/backup_export/data/backup_service.dart';
import 'package:hisaab/features/backup_export/data/csv_codec.dart';
import 'package:hisaab/features/backup_export/domain/backup_models.dart';
import 'package:hisaab/features/backup_export/presentation/backup_export_screen.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

class _Gw implements BackupFileGateway {
  _Gw(this.text);
  String? text;
  String? savedName;
  List<int>? saved;
  @override
  Future<String?> save(String fileName, List<int> bytes) async {
    savedName = fileName;
    saved = bytes;
    return fileName;
  }

  @override
  Future<String?> pickText() async => text;
}

class _Txs extends Mock implements TransactionRepository {}

class _Settings extends Mock implements SettingsRepository {}

class _FakeSvc extends BackupService {
  _FakeSvc(super.txs, super.settings);
  @override
  Future<({int count, String file})?> export(
    BackupFileGateway gateway, {
    required DateTime now,
  }) async {
    final f = await gateway.save('dhankosh-2026-10-21.csv', [1]);
    return (count: 1, file: f!);
  }

  @override
  Future<ImportReport> ingest(CsvImportResult parsed) async =>
      ImportReport(inserted: parsed.rows.length, skipped: 0);
}

void main() {
  // FR-24-04
  test('dec2 uses integer math, no sign or grouping', () {
    expect(dec2(245050), '2450.50');
    expect(dec2(5), '0.05');
    expect(dec2(99999999999900), '999999999999.00');
  });

  // FR-24-03
  test('header has the exact 15 columns', () {
    expect(
        csvHeader.join(','),
        'date,amount,currency,type,bank,account_last4,account_kind,'
        'merchant,category,channel,reference,balance,upi_id,note,hash');
    expect(exportCsv([]).trim(), csvHeader.join(','));
  });

  // FR-24-07..09: hand-written file from memory 24 section 10.
  test('hand-written minimal file imports with defaults and computed hash', () {
    final r = importCsv(
      'Type,Date,Amount,Memo\ndebit,2026-10-17T08:15:30Z,"250.00",lunch\n',
    );
    expect(r.badLines, 0);
    final p = r.rows.single;
    expect(p.amountMinor, 25000);
    expect(p.bankName, 'Imported');
    expect(p.currency, 'INR');
    expect(p.category, Category.other);
    expect(
      p.transactionHash,
      'a6abbb99d42490b8f91be1efc69a4bc498ae6823d474e5f279ce0718d0e50b00',
    );
  });

  // FR-24-07
  test('missing required columns throws', () {
    expect(
      () => importCsv('a,b\n1,2\n'),
      throwsA(
        isA<FormatException>().having((e) => e.message, 'm', csvNotExport),
      ),
    );
  });

  // FR-24-09
  test('bad lines are counted, unknown category falls back', () {
    final r = importCsv(
      'date,amount,type,category\n'
      '17/10/2026,10.00,DEBIT,FOOD\n'
      '2026-10-17T08:15:30Z,12.345,DEBIT,FOOD\n'
      '2026-10-17T08:15:30Z,10.00,EXPENSE,FOOD\n'
      '2026-10-17T08:15:30Z,10\n'
      '2026-10-17T08:15:30Z,"1,250.5",credit,FOODIE\n',
    );
    expect(r.badLines, 4);
    expect(r.rows.single.amountMinor, 125050);
    expect(r.rows.single.category, Category.other);
  });

  group('with ledger', () {
    late TestEnv env;
    setUp(() => env = TestEnv());
    tearDown(() => env.close());

    // FR-24-16, FR-24-10, FR-24-04: quoting, unicode, large amounts.
    test('round trip keeps totals and a second import adds nothing', () async {
      await env.ingest(
        parsed(
          amountMinor: 9999999999900,
          merchant: 'Café, "Ramu" नमस्ते',
          ref: 'R1',
          balance: 4521000,
        ),
      );
      await env.ingest(
        parsed(
          amountMinor: 5,
          type: TransactionType.credit,
          ref: 'R2',
          time: t0 + hour,
          merchant: 'Line\nbreak',
          category: Category.other,
        ),
      );
      final svc = BackupService(env.txs, env.settings);
      final out = await svc.buildCsv();
      expect(out.count, 2);
      expect(out.csv, contains('"Café, ""Ramu""'));
      expect(out.csv, contains(',99999999999.00,'));
      expect(out.csv, contains('"Line\nbreak"'));

      final env2 = TestEnv();
      addTearDown(env2.close);
      final svc2 = BackupService(env2.txs, env2.settings);
      final rep = await svc2.ingest(await svc2.parse(out.csv));
      expect(rep.inserted, 2);
      final a = await svc.allTransactions();
      final b = await svc2.allTransactions();
      int sum(List<LedgerTx> l) => l.fold<int>(0, (s, t) => s + t.amountMinor);
      expect(sum(b), sum(a));
      expect(
        b.map((t) => t.merchant).toSet(),
        a.map((t) => t.merchant).toSet(),
      );
      expect(
        b.map((t) => t.balanceMinor).toSet(),
        a.map((t) => t.balanceMinor).toSet(),
      );

      final again = await svc2.ingest(await svc2.parse(out.csv));
      expect(again.inserted, 0);
      expect(again.skipped, 2);
      expect((await svc2.allTransactions()).length, 2);
    });
  });

  // FR-24-02, FR-24-05
  testWidgets('screen exports and imports with confirm', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gw = _Gw(
      'date,amount,type\n2026-10-17T08:15:30Z,50.00,DEBIT\n',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupFileGatewayProvider.overrideWithValue(gw),
          backupServiceProvider
              .overrideWithValue(_FakeSvc(_Txs(), _Settings())),
          lastExportProvider.overrideWith((ref) async => 0),
          lastFullBackupProvider.overrideWith((ref) async => 0),
        ],
        child: const MaterialApp(home: BackupExportScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No export yet'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('backup-export')),
        matching: find.text('Export'),
      ),
    );
    await tester.pumpAndSettle();
    expect(gw.savedName, matches(r'^dhankosh-\d{4}-\d{2}-\d{2}\.csv$'));
    expect(find.textContaining('Exported 1 transactions'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('backup-import')),
        matching: find.text('Import'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Import transactions?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-import-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Imported 1, skipped 0'), findsOneWidget);

    gw.text = 'x,y\n1,2\n';
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('backup-import')),
        matching: find.text('Import'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Import failed: Not a DhanKosh'),
      findsOneWidget,
    );
  });
}

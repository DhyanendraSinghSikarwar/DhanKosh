import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/backup_providers.dart';
import 'package:hisaab/features/backup_export/data/report_service.dart';
import 'package:hisaab/features/backup_export/domain/blob_gateway.dart';
import 'package:hisaab/features/backup_export/presentation/reports_section.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_repository.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:hisaab/shared/report/report_document.dart';
import 'package:mocktail/mocktail.dart';

class _Tx extends Mock implements TransactionRepository {}

class _Budgets extends Mock implements BudgetRepository {}

class _Holdings extends Mock implements HoldingRepository {}

class _Blob implements BlobGateway {
  @override
  Future<String?> saveFile(String n, List<int> b, String m) async => null;
  @override
  Future<Uint8List?> pickBytes() async => null;
}

class _Svc extends ReportService {
  _Svc()
      : super(
          txs: _Tx(),
          budgets: _Budgets(),
          holdings: _Holdings(),
          netWorth: () async => null,
        );
  final asked = <String>[];
  final saved = <String>[];

  ReportDocument _doc(String stem) => ReportDocument(
        title: 't',
        subtitle: 's',
        fileStem: stem,
        footer: 'f',
        sections: const [],
      );

  @override
  Future<ReportDocument> month(int year, int month) async {
    asked.add('month $year-$month');
    return _doc('m');
  }

  @override
  Future<ReportDocument> year(int year) async {
    asked.add('year $year');
    return _doc('y');
  }

  @override
  Future<ReportDocument> portfolio(DateTime today) async {
    asked.add('portfolio');
    return _doc('p');
  }

  @override
  Future<String?> save(BlobGateway gateway, ReportDocument doc) async {
    saved.add(doc.fileStem);
    return '${doc.fileStem}.pdf';
  }
}

void main() {
  // FR-24-29, FR-24-30
  testWidgets('summary choices and portfolio build and save a PDF', (t) async {
    final svc = _Svc();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          reportServiceProvider.overrideWithValue(svc),
          blobGatewayProvider.overrideWithValue(_Blob()),
        ],
        child: const MaterialApp(home: Scaffold(body: ReportsSection())),
      ),
    );
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('report-summary')),
        matching: find.text('Create'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('report-last-year')));
    await t.pumpAndSettle();
    expect(svc.asked.single, startsWith('year '));
    expect(svc.saved, ['y']);
    expect(find.text('Saved y.pdf'), findsOneWidget);

    await t.tap(
      find.descendant(
        of: find.byKey(const Key('report-portfolio')),
        matching: find.text('Create'),
      ),
    );
    await t.pumpAndSettle();
    expect(svc.asked.last, 'portfolio');
    expect(svc.saved.last, 'p');
  });
}

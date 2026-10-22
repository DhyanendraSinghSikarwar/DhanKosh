import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_outcome.dart';
import 'package:hisaab/features/statement_import/presentation/statement_detail_screen.dart';

void main() {
  // FR-05-18, FR-05-20: detail shows counts, balance applied and mismatch.
  testWidgets('detail shows outcome and holdings mismatch warning', (t) async {
    const s = Statement(
      id: 4,
      key: 'file:4',
      source: StatementSource.file,
      sender: 'x.pdf',
      fileName: 'x.pdf',
      receivedAt: 1,
      status: StatementStatus.parsed,
      processedAt: 1,
      transactionCount: 3,
      holdingCount: 2,
      totals: StatementTotals(),
      bankName: 'Demo Bank',
      filePath: '/m/x.bin',
    );
    const o = StatementOutcome(
      added: 3,
      merged: 1,
      holdingsUpdated: 2,
      effect: AccountEffect(
        kind: AccountEffectKind.closingBalance,
        amountMinor: 123400,
      ),
      mismatch:
          HoldingsMismatch(statedValueMinor: 100000, rowsValueMinor: 90000),
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          statementDetailProvider(4)
              .overrideWith((_) async => const StatementDetail(s, o)),
        ],
        child: const MaterialApp(home: StatementDetailScreen(id: 4)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Demo Bank'), findsOneWidget);
    expect(find.text('Rows merged'), findsOneWidget);
    expect(find.byKey(const Key('statement-mismatch')), findsOneWidget);
    expect(find.text('₹1,234.00'), findsOneWidget);
    expect(find.byKey(const Key('statement-read-again')), findsOneWidget);
  });
}

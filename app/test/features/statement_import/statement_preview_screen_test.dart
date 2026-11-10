// FR-05-34: the preview lists each row, lets the user untick, and returns
// the unticked rows.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/statement_preview.dart';
import 'package:hisaab/features/statement_import/presentation/statement_preview_screen.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';

import '../../support/parsed.dart';

void main() {
  StatementPreview plan() => StatementPreview(
        file: PickedFile(name: 'a.pdf', bytes: Uint8List(0)),
        rows: [
          PreviewRow(index: 0, tx: parsed(), kind: PlanKind.added),
          PreviewRow(
            index: 1,
            tx: parsed(merchant: 'Zepto', amountMinor: 12000),
            kind: PlanKind.merged,
            existingId: 7,
          ),
          PreviewRow(
            index: 2,
            tx: parsed(merchant: 'Old', amountMinor: 100),
            kind: PlanKind.skipped,
            reason: 'already_processed',
          ),
        ],
      );

  testWidgets('skipped rows start unticked; confirm returns the unticked',
      (tester) async {
    Set<int>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => result = await Navigator.push<Set<int>?>(
              c,
              MaterialPageRoute(
                builder: (_) => StatementPreviewScreen(preview: plan()),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Import 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-row-1')));
    await tester.pump();
    expect(find.text('Import 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('preview-confirm')));
    await tester.pumpAndSettle();
    expect(result, {1, 2});
  });

  testWidgets('cancel returns null', (tester) async {
    Set<int>? result = {9};
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => result = await Navigator.push<Set<int>?>(
              c,
              MaterialPageRoute(
                builder: (_) => StatementPreviewScreen(preview: plan()),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-cancel')));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}

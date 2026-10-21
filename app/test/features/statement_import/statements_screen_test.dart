import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/usecases/import_statement.dart';
import 'package:hisaab/features/statement_import/presentation/statements_screen.dart';

class _FakeImport implements ImportStatement {
  final unlocked = <(int, String, bool)>[];
  final deleted = <int>[];
  ImportResult next = const ImportWrongPassword(1);

  @override
  Future<ImportResult> unlock(
    int id,
    String password, {
    bool remember = false,
    String? label,
  }) async {
    unlocked.add((id, password, remember));
    return next;
  }

  @override
  Future<void> delete(int id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker implements FileSource {
  @override
  Future<PickedFile?> pick() async => null;
}

Statement _s(int id, String name, StatementStatus st, {int rows = 0}) =>
    Statement(
      id: id,
      key: 'file:$id',
      source: StatementSource.file,
      sender: name,
      fileName: name,
      receivedAt: id,
      status: st,
      processedAt: id,
      transactionCount: rows,
      holdingCount: 0,
      totals: const StatementTotals(),
      bankName: st == StatementStatus.parsed ? 'Test Bank' : null,
    );

void main() {
  final fake = _FakeImport();
  final rows = [
    _s(2, 'locked.pdf', StatementStatus.locked),
    _s(1, 'march.pdf', StatementStatus.parsed, rows: 12),
  ];

  Future<void> pump(WidgetTester t, List<Statement> list) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          statementsProvider.overrideWith((_) => Stream.value(list)),
          lockedStatementCountProvider.overrideWith(
            (_) => Stream.value(list.where((s) => s.isLocked).length),
          ),
          importStatementProvider.overrideWithValue(fake),
          statementFileSourceProvider.overrideWithValue(_Picker()),
        ],
        child: const MaterialApp(home: StatementsScreen()),
      ),
    );
    await t.pump();
  }

  // FR-05-19: list with status, locked banner, delete.
  testWidgets('list shows status, locked banner and deletes', (t) async {
    await pump(t, rows);
    expect(find.text('march.pdf'), findsOneWidget);
    expect(find.text('Test Bank · 12 rows'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.byKey(const Key('statements-locked-banner')), findsOneWidget);
    expect(find.text('1 locked'), findsOneWidget);

    await t.tap(find.byKey(const Key('statement-delete-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('statement-delete-confirm')));
    await t.pumpAndSettle();
    expect(fake.deleted, [1]);
  });

  testWidgets('empty list and no banner', (t) async {
    await pump(t, const []);
    expect(find.text('No statements yet.'), findsOneWidget);
    expect(find.byKey(const Key('statements-locked-banner')), findsNothing);
  });

  // FR-05-12: password sheet, wrong then right, remember flag.
  testWidgets('password sheet: wrong password keeps sheet, then unlocks',
      (t) async {
    await pump(t, rows);
    await t.tap(find.byKey(const Key('statement-2')));
    await t.pumpAndSettle();
    expect(find.text('Unlock statement'), findsOneWidget);

    await t.enterText(find.byKey(const Key('unlock-password')), 'bad');
    await t.tap(find.byKey(const Key('unlock-submit')));
    await t.pumpAndSettle();
    expect(find.text('Wrong password.'), findsOneWidget);
    expect(fake.unlocked.last, (2, 'bad', false));

    fake.next = const ImportDone(
      statementId: 2,
      added: 3,
      merged: 1,
      review: 0,
      holdings: 0,
    );
    await t.enterText(find.byKey(const Key('unlock-password')), 'good');
    await t.tap(find.byKey(const Key('unlock-remember')));
    await t.tap(find.byKey(const Key('unlock-submit')));
    await t.pumpAndSettle();
    expect(fake.unlocked.last, (2, 'good', true));
    expect(find.text('Unlock statement'), findsNothing);
    expect(find.text('3 added, 1 merged.'), findsOneWidget);
  });
}

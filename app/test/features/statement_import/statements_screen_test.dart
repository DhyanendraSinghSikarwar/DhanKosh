import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/share_in_providers.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/statement_preview.dart';
import 'package:hisaab/features/statement_import/domain/usecases/import_statement.dart';
import 'package:hisaab/features/statement_import/presentation/statements_screen.dart';

class _FakeImport implements ImportStatement {
  final unlocked = <(int, String, bool)>[];
  final deleted = <int>[];
  final imported = <String>[];
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
  Future<ImportResult> call(
    PickedFile file, {
    Set<int> skipRows = const {},
  }) async {
    imported.add(file.name);
    return next;
  }

  @override
  Future<StatementPreview?> preview(PickedFile file) async => null;

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

  // FR-05-26: a shared file in the inbox is imported on arrival, once.
  testWidgets('shared file is imported when the screen opens', (t) async {
    fake.imported.clear();
    final c = ProviderContainer(
      overrides: [
        statementsProvider.overrideWith((_) => Stream.value(rows)),
        lockedStatementCountProvider.overrideWith((_) => Stream.value(0)),
        importStatementProvider.overrideWithValue(fake),
        statementFileSourceProvider.overrideWithValue(_Picker()),
      ],
    );
    addTearDown(c.dispose);
    c.read(sharedInboxProvider.notifier).put(
          PickedFile(name: 'shared.pdf', bytes: Uint8List(3)),
        );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: StatementsScreen()),
      ),
    );
    await t.pump();
    await t.pump();
    expect(fake.imported, ['shared.pdf']);
    expect(c.read(sharedInboxProvider), isNull);
    await t.pumpAndSettle();
    expect(fake.imported, hasLength(1));
  });

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

  // FR-05-30: the mail's subject says what kind of statement is locked.
  group('email statements (FR-05-30)', () {
    final mail = Statement(
      id: 7,
      key: 'm1#pdf0',
      source: StatementSource.email,
      sender: 'estatement@examplebank.in',
      fileName: 'stmt.pdf',
      receivedAt: DateTime(2026, 11, 3, 9, 5).millisecondsSinceEpoch,
      status: StatementStatus.locked,
      processedAt: 7,
      transactionCount: 0,
      holdingCount: 0,
      totals: const StatementTotals(),
      subject: 'Example Bank Credit Card Statement - card ending 4821',
      emailText: 'Dear Customer, your statement is attached. '
          'The password is the first four letters of your name and your DOB.',
    );

    testWidgets('the unlock sheet shows the subject and can open the mail',
        (t) async {
      await pump(t, [mail]);
      // The list row itself names the kind of statement.
      expect(
        find.textContaining('Credit Card Statement - card ending 4821'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('statement-7')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('unlock-subject')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('unlock-subject'))).data,
        contains('card ending 4821'),
      );
      expect(find.textContaining('estatement@examplebank.in'), findsWidgets);

      await t.tap(find.byKey(const Key('unlock-view-mail')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mail-subject')), findsOneWidget);
      expect(find.byKey(const Key('mail-body')), findsOneWidget);
      expect(find.textContaining('first four letters'), findsOneWidget);
    });

    testWidgets('each emailed statement has a View email button', (t) async {
      await pump(t, [mail, ...rows]);
      expect(find.byKey(const Key('statement-mail-7')), findsOneWidget);
      // A statement imported from a file has no mail to show.
      expect(find.byKey(const Key('statement-mail-1')), findsNothing);
      await t.tap(find.byKey(const Key('statement-mail-7')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mail-body')), findsOneWidget);
    });

    testWidgets('a file statement shows only its file name', (t) async {
      await pump(t, rows);
      await t.tap(find.byKey(const Key('statement-2')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('unlock-subject')), findsNothing);
      expect(find.byKey(const Key('unlock-view-mail')), findsNothing);
      expect(find.text('locked.pdf'), findsWidgets);
    });

    testWidgets('a mail with no kept text says so', (t) async {
      const bare = Statement(
        id: 8,
        key: 'm2#pdf0',
        source: StatementSource.email,
        sender: 'a@b.in',
        fileName: 's.pdf',
        receivedAt: 1,
        status: StatementStatus.parsed,
        processedAt: 1,
        transactionCount: 2,
        holdingCount: 0,
        totals: StatementTotals(),
        subject: 'Your statement',
      );
      await pump(t, [bare]);
      await t.tap(find.byKey(const Key('statement-mail-8')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('mail-empty')), findsOneWidget);
      expect(find.byKey(const Key('mail-subject')), findsOneWidget);
    });
  });
}

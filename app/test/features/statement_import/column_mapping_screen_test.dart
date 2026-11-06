// F-05: the column mapping screen and the balance check card (FR-05-28,
// FR-05-29). Every row is synthetic.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/statement_import/data/column_layout_store_impl.dart';
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/usecases/import_mapped_sheet.dart';
import 'package:hisaab/features/statement_import/presentation/column_mapping_screen.dart';
import 'package:parser_core/parser_core.dart' as pc;

import '../../support/fake_ledger.dart' show FakeAccountRepo;
import '../../support/test_env.dart';
import 'import_statement_test.dart' show FakeSheets, MemFiles;

const _csv = '''
Example Bank Ltd,,,,
Account Statement for A/c XXXXXX4321,,,,
Date,Narration,Withdrawal Amt.,Deposit Amt.,Closing Balance
01/11/2026,UPI/612345678901/GROCERY MART/okaxis,250.00,,9750.00
02/11/2026,SALARY ACME LTD,,50000.00,59750.00
03/11/2026,ATM WDL,2000.00,,57750.00
''';

PickedFile _file(String text) => PickedFile(
      name: 'stmt.csv',
      bytes: Uint8List.fromList(utf8.encode(text)),
    );

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<void> pump(
    WidgetTester t,
    PickedFile file, {
    List<Account> accounts = const [],
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(900, 3200);
    addTearDown(t.view.reset);
    final use = ImportMappedSheet(
      sheets: FakeSheets(),
      statements: StatementRepositoryImpl(env.db),
      files: MemFiles(),
      ledger: env.txs,
      accounts: env.accounts,
      layouts: ColumnLayoutStoreImpl(SettingsKeyValueStore(env.settings)),
      clock: () => env.clock,
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          importMappedSheetProvider.overrideWithValue(use),
          accountRepositoryProvider
              .overrideWithValue(FakeAccountRepo(accounts)),
        ],
        child: MaterialApp(home: ColumnMappingScreen(file: file)),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump();
    await t.pump();
  }

  /// A real account in the ledger, so rows can be filed under it.
  Future<Account> makeAccount(WidgetTester t) async {
    final id = (await t.runAsync(
      () => env.accounts.create(
        const NewAccount(
          kind: pc.AccountKind.account,
          bankName: 'Example Bank',
          last4: '4321',
        ),
      ),
    ))!;
    return Account(
      id: id,
      bankName: 'Example Bank',
      last4: '4321',
      kind: pc.AccountKind.account,
      createdAt: 0,
    );
  }

  testWidgets('guesses the header and columns and shows how it reads',
      (t) async {
    final acct = await makeAccount(t);
    await pump(t, _file(_csv), accounts: [acct]);
    expect(find.text('Header row: 3'), findsOneWidget);
    expect(find.byKey(const Key('map-count')), findsOneWidget);
    expect(find.text('3 rows'), findsOneWidget);
    expect(find.byKey(const Key('map-adds-up')), findsOneWidget);
    // The preamble names the account, so it is pre-selected.
    final dd = t.widget<DropdownButtonFormField<int?>>(
      find.byKey(const Key('map-account')),
    );
    expect(dd.initialValue, acct.id);
    expect(find.byKey(const Key('map-import')), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('map-import'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('moving the header row re-reads the file', (t) async {
    await pump(t, _file(_csv));
    await t.tap(find.byKey(const Key('map-header-up')));
    await t.pump();
    expect(find.text('Header row: 2'), findsOneWidget);
    // Row 2 is the "Account Statement" line: nothing reads from it.
    expect(find.byKey(const Key('map-empty')), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('map-import'))).onPressed,
      isNull,
    );
    await t.tap(find.byKey(const Key('map-header-down')));
    await t.pump();
    expect(find.text('3 rows'), findsOneWidget);
  });

  testWidgets('swapping to one amount column breaks the reading', (t) async {
    await pump(t, _file(_csv));
    await t.tap(find.text('One amount'));
    await t.pump();
    // Debit moved into Amount, Credit cleared: the credit rows now fail.
    expect(find.byKey(const Key('map-amount')), findsOneWidget);
    expect(find.byKey(const Key('map-debit')), findsNothing);
    // Going back restores split mode.
    await t.tap(find.text('Debit and credit'));
    await t.pump();
    expect(find.byKey(const Key('map-debit')), findsOneWidget);
  });

  testWidgets('wrong columns are flagged when the balances do not add up',
      (t) async {
    await pump(t, _file(_csv));
    expect(find.byKey(const Key('map-adds-up')), findsOneWidget);
    // Swap Debit and Credit: every row now reads the wrong way round.
    await t.tap(find.byKey(const Key('map-debit')));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('D · Deposit Amt.').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('map-credit')));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('C · Withdrawal Amt.').last);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('map-breaks')), findsOneWidget);
    expect(find.byKey(const Key('map-adds-up')), findsNothing);
  });

  testWidgets('Import files the rows and shows the balance check', (t) async {
    final acct = await makeAccount(t);
    await pump(t, _file(_csv), accounts: [acct]);
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('map-import')));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('result-counts')), findsOneWidget);
    expect(find.text('3 added'), findsOneWidget);
    // The account has no balance of its own yet, so there is nothing to
    // compare the statement with.
    expect(find.text('Balance check'), findsOneWidget);
    expect(find.text('unknown'), findsOneWidget);
    expect(await t.runAsync(() => env.count('transactions')), 3);
  });

  testWidgets('a file that cannot be opened says why', (t) async {
    await pump(
      t,
      PickedFile(
        name: 'a.xls',
        bytes: Uint8List.fromList([0xd0, 0xcf, 0x11, 0xe0, 0, 0]),
      ),
    );
    expect(find.byKey(const Key('map-failure')), findsOneWidget);
  });
}

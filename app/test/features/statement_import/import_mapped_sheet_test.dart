// F-05: a spreadsheet read through a column mapping, filed under an account,
// and checked against the app's balance (FR-05-28, FR-05-29). Synthetic data.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/statement_import/data/column_layout_store_impl.dart';
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/usecases/import_mapped_sheet.dart';
import 'package:parser_core/parser_core.dart' as pc;

import '../../support/test_env.dart';
import 'import_statement_test.dart' show FakeSheets, MemFiles;

const _csv = '''
Example Bank Ltd,,,,
Account Statement for A/c XXXXXX4321,,,,
Date,Narration,Withdrawal Amt.,Deposit Amt.,Closing Balance
01/11/2026,UPI/612345678901/GROCERY MART/okaxis,250.00,,9750.00
02/11/2026,SALARY ACME LTD,,50000.00,59750.00
03/11/2026,ATM WDL,2000.00,,57750.00
Total,,,,
''';

PickedFile _file(String text, [String name = 'stmt.csv']) =>
    PickedFile(name: name, bytes: Uint8List.fromList(utf8.encode(text)));

void main() {
  late TestEnv env;
  late ImportMappedSheet use;
  late MemFiles files;

  setUp(() {
    env = TestEnv();
    files = MemFiles();
    use = ImportMappedSheet(
      sheets: FakeSheets(),
      statements: StatementRepositoryImpl(env.db),
      files: files,
      ledger: env.txs,
      accounts: env.accounts,
      layouts: ColumnLayoutStoreImpl(SettingsKeyValueStore(env.settings)),
      clock: () => env.clock,
    );
  });
  tearDown(() => env.close());

  Future<int> account({int? balance, int? at}) async {
    final id = (await env.accounts.create(
      const NewAccount(
        kind: pc.AccountKind.account,
        bankName: 'Example Bank',
        last4: '4321',
        accountType: AccountType.savings,
      ),
    ))!;
    if (balance != null) {
      await env.accounts.updateBalance(id, at: at!, balanceMinor: balance);
    }
    return id;
  }

  test('reads a CSV into one sheet and refuses what it cannot open', () {
    final sheets = use.read(_file(_csv));
    expect(sheets, hasLength(1));
    expect(sheets.single.rows.length, greaterThan(5));
    expect(
      () => use.read(
        PickedFile(
          name: 'a.xls',
          bytes: Uint8List.fromList([0xd0, 0xcf, 0x11, 0xe0, 0, 0]),
        ),
      ),
      throwsA(
        isA<SheetOpenException>()
            .having((e) => e.reason, 'reason', UnsupportedReason.xls),
      ),
    );
    expect(
      () => use.read(_file('x', 'a.pdf')),
      throwsA(isA<SheetOpenException>()),
    );
  });

  test('files the rows under the account and reports a matching balance',
      () async {
    final rows = use.read(_file(_csv)).single.rows;
    final header = pc.StatementTable.guessHeaderRow(rows);
    expect(header, 2);
    final mapping = pc.StatementTable.guessMapping(rows, header);
    // The app already holds the bank's own figure for 3 Nov.
    final endOf3 = ImportMappedSheet.endOfDay(
      DateTime.utc(2026, 11, 3).millisecondsSinceEpoch ~/ 86400000,
    );
    final id = await account(balance: 5775000, at: endOf3);

    final r = await use.commit(
      file: _file(_csv),
      rows: rows,
      mapping: mapping,
      accountId: id,
    );
    expect(r.added, 3);
    expect(r.skipped, 1);
    expect(await env.count('transactions'), 3);
    expect(r.addsUp, isTrue);
    expect(r.comparison!.statementMinor, 5775000);
    expect(r.comparison!.matches, isTrue);
    expect(r.canSetBalance, isFalse);

    // The rows carry the account, the source and no stray balance.
    final t = await env.db
        .customSelect(
          'SELECT account_id, source, balance_minor FROM transactions t '
          'JOIN transaction_sources s ON s.transaction_id = t.id '
          'ORDER BY t.id LIMIT 1',
        )
        .getSingle();
    expect(t.read<int>('account_id'), id);
    expect(t.read<String>('source'), 'STATEMENT');
    expect(t.read<int?>('balance_minor'), isNull);
  });

  test('a different balance is reported and can be taken when it adds up',
      () async {
    final rows = use.read(_file(_csv)).single.rows;
    final mapping = pc.StatementTable.guessMapping(rows, 2);
    // The app thinks the balance was lower on 3 Nov.
    final endOf3 = ImportMappedSheet.endOfDay(
      DateTime.utc(2026, 11, 3).millisecondsSinceEpoch ~/ 86400000,
    );
    final id = await account(balance: 5575000, at: endOf3 - 1000);
    final r = await use.commit(
      file: _file(_csv),
      rows: rows,
      mapping: mapping,
      accountId: id,
    );
    expect(r.comparison!.matches, isFalse);
    expect(r.comparison!.differenceMinor, 200000);
    expect(r.canSetBalance, isTrue);

    expect(await use.useStatementBalance(id, r.comparison!), isTrue);
    final a = (await env.accounts.byId(id))!;
    expect(a.latestBalanceMinor, 5775000);
  });

  test('a newer bank balance is never overwritten', () async {
    final rows = use.read(_file(_csv)).single.rows;
    final mapping = pc.StatementTable.guessMapping(rows, 2);
    final later = ImportMappedSheet.endOfDay(
      DateTime.utc(2026, 11, 20).millisecondsSinceEpoch ~/ 86400000,
    );
    final id = await account(balance: 4000000, at: later);
    final r = await use.commit(
      file: _file(_csv),
      rows: rows,
      mapping: mapping,
      accountId: id,
    );
    expect(r.comparison, isNotNull);
    expect(await use.useStatementBalance(id, r.comparison!), isFalse);
    expect((await env.accounts.byId(id))!.latestBalanceMinor, 4000000);
  });

  test('swapped columns break the balances, so the balance is not offered',
      () async {
    final rows = use.read(_file(_csv)).single.rows;
    final good = pc.StatementTable.guessMapping(rows, 2);
    final swapped = good.copyWith(debit: good.credit, credit: good.debit);
    final id = await account(balance: 1, at: 1);
    final r = await use.commit(
      file: _file(_csv),
      rows: rows,
      mapping: swapped,
      accountId: id,
    );
    expect(r.addsUp, isFalse);
    expect(r.canSetBalance, isFalse);
  });

  test('importing the same file twice books nothing twice', () async {
    final rows = use.read(_file(_csv)).single.rows;
    final mapping = pc.StatementTable.guessMapping(rows, 2);
    final id = await account();
    await use.commit(
      file: _file(_csv),
      rows: rows,
      mapping: mapping,
      accountId: id,
    );
    final again = await use.commit(
      file: _file(_csv),
      rows: rows,
      mapping: mapping,
      accountId: id,
    );
    expect(again.added, 0);
    expect(await env.count('transactions'), 3);
    expect(await env.count('statements'), 1);
  });

  test('with no account the rows are filed under "Statement"', () async {
    final rows = use.read(_file(_csv)).single.rows;
    final mapping = pc.StatementTable.guessMapping(rows, 2);
    final r = await use.commit(file: _file(_csv), rows: rows, mapping: mapping);
    expect(r.added, 3);
    expect(r.comparison, isNull);
    final b = await env.db
        .customSelect('SELECT DISTINCT bank_name AS b FROM transactions')
        .getSingle();
    expect(b.read<String>('b'), 'Statement');
  });

  test('the confirmed layout is remembered for the next file', () async {
    final rows = use.read(_file(_csv)).single.rows;
    final mapping =
        pc.StatementTable.guessMapping(rows, 2).copyWith(balance: 4);
    await use.commit(file: _file(_csv), rows: rows, mapping: mapping);
    final saved = await use.savedFor(rows, 2);
    expect(saved, mapping);
    await use.forgetLayouts();
    expect(await use.savedFor(rows, 2), isNull);
  });
}

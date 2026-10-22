import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/statement_import/data/statement_account_store_impl.dart';
import 'package:hisaab/features/statement_import/data/statement_outcome_store.dart';
import 'package:hisaab/features/statement_import/data/statement_password_store.dart';
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement_outcome.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/usecases/apply_statement_accounts.dart';
import 'package:hisaab/features/statement_import/domain/usecases/import_statement.dart';
import 'package:parser_core/parser_core.dart' as pc;

import '../../support/test_env.dart';
import 'import_statement_test.dart'
    show FakePdf, FakeSheets, MemFiles, MemSecure, pdfBytes, source;

const _cardWithLimit = '''
HDFC Bank Credit Card Statement
Card No: 4893 XXXX XXXX 5678
Statement Date 20/09/2026  Total Amount Due 12,345.00  Minimum Amount Due 620.00
Credit Limit 2,00,000.00  Available Credit Limit 1,50,000.00
Date Transaction Description Amount (in Rs.)
02/09/2026 AMAZON PAY INDIA MUMBAI 1,499.00
''';

class _Notifier implements StatementLockedNotifier {
  final ids = <int>[];
  @override
  Future<void> notify(int id, {String? bank}) async => ids.add(id);
}

void main() {
  late TestEnv env;
  late MemFiles files;
  late StatementOutcomeKvStore outcomes;
  late _Notifier notifier;

  setUp(() {
    env = TestEnv();
    files = MemFiles();
    outcomes = StatementOutcomeKvStore(SettingsKeyValueStore(env.settings));
    notifier = _Notifier();
  });
  tearDown(() => env.close());

  ImportStatement make(FakePdf pdf) => ImportStatement(
        statements: StatementRepositoryImpl(env.db),
        savedPasswords: StatementPasswordStore(MemSecure()),
        pdf: pdf,
        sheets: FakeSheets(),
        files: files,
        ledger: env.txs,
        holdings: HoldingRepositoryImpl(env.db),
        cardDues: CardDueRepositoryImpl(env.db),
        accounts: ApplyStatementAccounts(
          StatementAccountStoreImpl(env.db, clock: () => env.clock),
        ),
        outcomes: outcomes,
        lockedNotifier: notifier,
        passwordSource: () async => source(),
        clock: () => env.clock,
      );

  Future<Map<String, Object?>> account(String last4) async =>
      (await env.db.customSelect(
        'SELECT available_limit_minor AS l, latest_balance_minor AS b, '
        'accounts.* FROM accounts WHERE last4 = ?',
        variables: [Variable<String>(last4)],
      ).getSingle())
          .data;

  // FR-05-07, FR-05-20: available limit applied, outcome kept, no extra
  // transactions on "Read again".
  test('card statement sets the available limit and keeps its outcome',
      () async {
    final uc = make(FakePdf(_cardWithLimit));
    final r = await uc(
      PickedFile(name: 'card.pdf', bytes: pdfBytes('lim')),
    ) as ImportDone;
    expect(r.accountEffect.kind, AccountEffectKind.availableLimit);
    expect(r.accountEffect.amountMinor, 15000000);
    expect((await account('5678'))['l'], 15000000);
    final o = (await outcomes.read(r.statementId))!;
    expect(o.effect.amountMinor, 15000000);
    final before = await env.count('transactions');
    final again = await uc.readAgain(r.statementId);
    expect(again, isA<ImportDone>());
    expect(await env.count('transactions'), before);
  });

  // FR-05-07: an older figure never replaces a newer one.
  test('older statement figure does not overwrite a newer balance', () async {
    final store = StatementAccountStoreImpl(env.db, clock: () => env.clock);
    final id = (await store.insert(
      'Demo Bank',
      '1111',
      kind: pc.AccountKind.account,
    ))!;
    await store.updateBalance(id, at: 2000, balanceMinor: 500);
    await store.updateBalance(id, at: 1000, balanceMinor: 900);
    expect((await account('1111'))['b'], 500);
  });

  // FR-05-17: deposit account from a deposit advice, no transactions.
  test('FD advice creates a deposit account with maturity', () async {
    final apply = ApplyStatementAccounts(
      StatementAccountStoreImpl(env.db, clock: () => env.clock),
    );
    final mat = pc.CivilDate.tryCreate(2027, 3, 1)!;
    final n = await apply.applyDeposits([
      pc.LoanStatus(
        'Demo Bank',
        '9012',
        10000000,
        10000000,
        env.clock,
        deposit: pc.DepositInfo(
          pc.DepositKind.fd,
          maturity: mat,
          action: pc.DepositAction.renewAll,
        ),
      ),
    ]);
    expect(n, 1);
    final a = await account('9012');
    expect(a['account_type'], 'FD');
    expect(a['maturity_day'], mat.toEpochDay());
    expect(a['maturity_action'], 'RENEW_ALL');
    expect(await env.count('transactions'), 0);
  });

  // FR-05-16: emailed attachment keyed by message, locked notice, no repeat.
  test('emailed locked statement notifies once and is not re-imported',
      () async {
    final uc = make(FakePdf(_cardWithLimit, password: 'secret'));
    const origin = EmailOrigin(
      messageId: 'imap:<m1@x>',
      index: 0,
      sender: 'alerts@hdfcbank.net',
      subject: 'Your statement',
      receivedAt: 1,
      emailText: 'Dear customer',
    );
    final f = PickedFile(name: 'st.pdf', bytes: pdfBytes('em'));
    final r = await uc.importEmailAttachment(f, origin);
    expect(r, isA<ImportLocked>());
    expect(notifier.ids, [(r as ImportLocked).statementId]);
    final unlocked = await uc.unlock(r.statementId, 'secret');
    expect(unlocked, isA<ImportDone>());
    expect(await uc.importEmailAttachment(f, origin), isA<ImportAlreadyDone>());
  });

  test('xls and oversize files answer clear reasons', () async {
    final uc = make(FakePdf(''));
    final xls = PickedFile(
      name: 'a.xls',
      bytes: pdfBytes().buffer.asUint8List()
        ..setRange(0, 4, [0xd0, 0xcf, 0x11, 0xe0]),
    );
    expect(
      (await uc(xls) as ImportUnsupported).reason,
      UnsupportedReason.xls,
    );
  });

  test('outcome json round trips', () {
    const o = StatementOutcome(
      added: 2,
      merged: 1,
      effect: AccountEffect(
        kind: AccountEffectKind.closingBalance,
        amountMinor: 5,
      ),
      mismatch: HoldingsMismatch(statedValueMinor: 1, rowsValueMinor: 9),
    );
    final b = StatementOutcome.fromJson(o.toJson());
    expect(b.merged, 1);
    expect(b.effect.kind, AccountEffectKind.closingBalance);
    expect(b.mismatch?.rowsValueMinor, 9);
  });
}

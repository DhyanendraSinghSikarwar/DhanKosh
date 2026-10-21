import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/statement_import/data/statement_password_store.dart';
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/password_candidates.dart';
import 'package:hisaab/features/statement_import/domain/password_source.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/usecases/import_statement.dart';

import '../../support/test_env.dart';

class MemSecure implements SecureStore {
  final m = <String, String>{};
  @override
  Future<String?> read(String key) async => m[key];
  @override
  Future<void> write(String key, String value) async => m[key] = value;
}

/// PDF reader that opens only with [password] (null = none needed).
class FakePdf implements PdfTextReader {
  FakePdf(this.text, {this.password, this.failure});
  final String text;
  final String? password;
  final PdfFailure? failure;
  final tries = <String?>[];

  @override
  Future<String> extractText(Uint8List bytes, {String? password}) async {
    tries.add(password);
    if (failure != null) throw PdfReadException(failure!);
    if (this.password == null || password == this.password) return text;
    throw PdfReadException(
      password == null ? PdfFailure.passwordRequired : PdfFailure.wrongPassword,
    );
  }
}

class FakeSheets implements SheetReader {
  @override
  List<List<String>> xlsxRows(Uint8List bytes) => const [];
}

class MemFiles implements StatementFileStore {
  final files = <String, Uint8List>{};
  @override
  Future<String> save(String name, Uint8List bytes) async {
    files['/m/$name'] = bytes;
    return '/m/$name';
  }

  @override
  Future<Uint8List?> read(String path) async => files[path];
  @override
  Future<void> delete(String path) async => files.remove(path);
}

const cardText = '''
HDFC Bank Credit Card Statement
Card No: 4893 XXXX XXXX 5678
Statement Date 20/09/2026  Total Amount Due 12,345.00  Minimum Amount Due 620.00
Date Transaction Description Amount (in Rs.)
02/09/2026 AMAZON PAY INDIA MUMBAI 1,499.00
05/09/2026 SWIGGY BANGALORE 456.50
10/09/2026 PAYMENT RECEIVED - THANK YOU 8,000.00 Cr
12/09/2026 REFUND FLIPKART 299.00 Cr
''';

const casText = '''
Consolidated Account Statement
Folio No: 1234567 / 89
128TSDGG-Axis Bluechip Fund - Direct Growth - ISIN: INF846K01EW2(Advisor: DIRECT)
Closing Unit Balance: 123.456 NAV on 30-Sep-2026: INR 45.67 Total Cost Value: 5,000.00 Market Value on 30-Sep-2026: INR 5,638.12
P8DG-Parag Parikh Flexi Cap Fund - Direct Plan Growth - ISIN: INF879O01027(Advisor: DIRECT)
Closing Unit Balance: 1,000.000 NAV on 30-Sep-2026: INR 80.10 Total Cost Value: 60,000.00 Market Value on 30-Sep-2026: INR 80,100.00
''';

Uint8List pdfBytes([String tag = 'a']) =>
    Uint8List.fromList([0x25, 0x50, 0x44, 0x46, ...utf8.encode(tag)]);

const _identity = Identity(name: 'A SHARMA', pan: 'ABCDE1234F');

PasswordSource source({Identity? id, List<String> saved = const []}) =>
    assemblePasswordSource(
      identity: id,
      profile: const UserProfile(),
      cardLast4s: const ['5678'],
      banks: const [],
      saved: saved,
    );

void main() {
  late TestEnv env;
  late MemSecure secure;
  late MemFiles files;
  late StatementRepositoryImpl statements;
  late StatementPasswordStore saved;
  late HoldingRepositoryImpl holdings;
  late CardDueRepositoryImpl dues;

  setUp(() {
    env = TestEnv();
    secure = MemSecure();
    files = MemFiles();
    statements = StatementRepositoryImpl(env.db);
    saved = StatementPasswordStore(secure);
    holdings = HoldingRepositoryImpl(env.db);
    dues = CardDueRepositoryImpl(env.db);
  });
  tearDown(() => env.close());

  ImportStatement make(FakePdf pdf, {PasswordSource? src}) => ImportStatement(
        statements: statements,
        savedPasswords: saved,
        pdf: pdf,
        sheets: FakeSheets(),
        files: files,
        ledger: env.txs,
        holdings: holdings,
        cardDues: dues,
        passwordSource: () async => src ?? source(),
        clock: () => env.clock,
      );

  PickedFile pdf([String tag = 'a']) =>
      PickedFile(name: 'card.pdf', bytes: pdfBytes(tag));

  // FR-05-01, FR-05-04, FR-05-08: rows go through the ledger.
  test('card statement rows are ingested once and re-import is refused',
      () async {
    final uc = make(FakePdf(cardText));
    final r = await uc(pdf());
    expect(r, isA<ImportDone>());
    final d = r as ImportDone;
    expect(d.added + d.merged + d.review, 4);
    expect(d.cardNotice, isTrue);
    expect(await env.count('transactions'), d.added + d.review);
    final row = (await statements.byId(d.statementId))!;
    expect(row.status, StatementStatus.parsed);
    expect(row.kind, StatementKind.creditCard);
    expect(row.last4, '5678');
    expect(row.transactionCount, 4);
    expect(row.totals.totalDueMinor, 1234500);
    expect(row.filePath, isNotNull);
    expect(await dues.notices(), hasLength(1));

    expect(await uc(pdf()), isA<ImportAlreadyDone>());
    expect(await env.count('transactions'), d.added + d.review);
  });

  // FR-05-14, FR-05-15.
  test('holdings from a CAS are recorded', () async {
    final r = await make(FakePdf(casText))(pdf('cas')) as ImportDone;
    expect(r.holdings, 2);
    expect(r.added, 0);
    expect(await holdings.list(), hasLength(2));
    final row = (await statements.byId(r.statementId))!;
    expect(row.holdingCount, 2);
  });

  // FR-05-09: none, derived, then saved.
  test('password tries run none, derived, saved in order', () async {
    final src = source(id: _identity, saved: const ['mine-1', 'mine-2']);
    final all = passwordCandidates(src);
    expect(all.length, greaterThan(5));
    expect(all.sublist(all.length - 2), ['mine-1', 'mine-2']);

    final derived = FakePdf(cardText, password: all[2]);
    expect(await make(derived, src: src)(pdf('p1')), isA<ImportDone>());
    expect(derived.tries, [null, all[0], all[1], all[2]]);

    final savedPdf = FakePdf(cardText, password: 'mine-2');
    expect(await make(savedPdf, src: src)(pdf('p2')), isA<ImportDone>());
    expect(savedPdf.tries, [null, ...all]);
  });

  // FR-05-11, FR-05-12, FR-05-13.
  test('locked path: lock, wrong password, unlock and remember', () async {
    final src = source(id: _identity);
    final fake = FakePdf(cardText, password: 'secret-pw');
    final uc = make(fake, src: src);
    final locked = await uc(pdf('lk')) as ImportLocked;
    final row = (await statements.byId(locked.statementId))!;
    expect(row.status, StatementStatus.locked);
    expect(await statements.watchLockedCount().first, 1);
    expect(files.files, hasLength(1));
    expect(await env.count('transactions'), 0);

    final wrong = await uc.unlock(locked.statementId, 'nope');
    expect(wrong, isA<ImportWrongPassword>());
    expect((await statements.byId(locked.statementId))!.isLocked, isTrue);

    final ok = await uc.unlock(
      locked.statementId,
      'secret-pw',
      remember: true,
      label: 'HDFC',
    );
    expect(ok, isA<ImportDone>());
    expect((ok as ImportDone).statementId, locked.statementId);
    expect(
      (await statements.byId(locked.statementId))!.status,
      StatementStatus.parsed,
    );
    expect(await statements.watchLockedCount().first, 0);
    expect((await saved.list()).single.label, 'HDFC');
    expect(await env.count('transactions'), greaterThan(0));
  });

  test('re-importing a locked file retries it', () async {
    final fake = FakePdf(cardText, password: 'pw');
    final uc = make(fake);
    final first = await uc(pdf('rt')) as ImportLocked;
    final again = await uc(pdf('rt'));
    expect(again, isA<ImportLocked>());
    expect((again as ImportLocked).statementId, first.statementId);
  });

  test('retryLocked opens statements once a password is saved', () async {
    final fake = FakePdf(cardText, password: 'pw');
    final uc = make(fake);
    await uc(pdf('r1'));
    expect(await uc.retryLocked(), 0);
    final withSaved = make(fake, src: source(saved: const ['pw']));
    expect(await withSaved.retryLocked(), 1);
    expect(await statements.locked(), isEmpty);
  });

  // FR-05-02: scanned PDFs are unsupported.
  test('scanned pdf is reported unsupported and stored unreadable', () async {
    final r = await make(FakePdf('', failure: PdfFailure.scanned))(pdf('sc'));
    expect(r, isA<ImportUnsupported>());
    expect((r as ImportUnsupported).reason, UnsupportedReason.scanned);
    final all = await statements.watchAll().first;
    expect(all.single.status, StatementStatus.unreadable);
  });

  // FR-05-05: protected sheets and unknown types.
  test('protected sheet and unknown type are unsupported', () async {
    final ole = Uint8List.fromList([
      0xd0, 0xcf, 0x11, 0xe0, //
      for (final c in 'EncryptedPackage'.codeUnits) ...[c, 0],
    ]);
    final uc = make(FakePdf(cardText));
    final p = await uc(PickedFile(name: 'x.xlsx', bytes: ole));
    expect((p as ImportUnsupported).reason, UnsupportedReason.protectedSheet);
    final row = (await statements.watchAll().first).single;
    expect(row.kind, StatementKind.protected);
    final u = await uc(
      PickedFile(name: 'x.bin', bytes: Uint8List.fromList([1, 2, 0, 3])),
    );
    expect((u as ImportUnsupported).reason, UnsupportedReason.unknownType);
  });

  test('delete removes row and stored file', () async {
    final uc = make(FakePdf(cardText));
    final d = await uc(pdf('dl')) as ImportDone;
    expect(files.files, hasLength(1));
    await uc.delete(d.statementId);
    expect(files.files, isEmpty);
    expect(await statements.byId(d.statementId), isNull);
  });

  test('sniffStatement reads bytes before names', () {
    expect(sniffStatement(pdfBytes(), 'a.csv'), StatementFileType.pdf);
    expect(
      sniffStatement(Uint8List.fromList(utf8.encode('a,b\n1,2')), 'a.csv'),
      StatementFileType.csv,
    );
    expect(
      sniffStatement(Uint8List.fromList([0x50, 0x4b, 3, 4]), 'a'),
      StatementFileType.xlsx,
    );
  });
}

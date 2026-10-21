import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_flow_source_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_paid_store_impl.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_actions.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_service.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/portfolio/data/net_worth_repository_impl.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/compute_net_worth.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_summary.dart';
import 'package:hisaab/features/profile/data/bank_identity_store.dart';
import 'package:hisaab/features/profile/domain/bank_identity.dart';
import 'package:hisaab/features/profile/domain/own_numbers.dart';
import 'package:hisaab/features/profile/domain/profile_draft.dart';
import 'package:hisaab/features/statement_import/data/statement_password_store.dart';
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/features/statement_import/domain/password_source.dart';
import 'package:hisaab/features/statement_import/domain/saved_password.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:parser_core/parser_core.dart' show AccountKind;

import '../../support/test_env.dart';

class MemSecure implements SecureStore {
  final m = <String, String>{};
  @override
  Future<String?> read(String key) async => m[key];
  @override
  Future<void> write(String key, String value) async => m[key] = value;
}

int ms(int y, int m, int d) =>
    DateTime.utc(y, m, d, 6, 30).millisecondsSinceEpoch;

NewStatement stmt(String key, {StatementStatus s = StatementStatus.parsed}) =>
    NewStatement(
      key: key,
      source: StatementSource.file,
      sender: 'me',
      fileName: 'a.pdf',
      receivedAt: 10,
      processedAt: 11,
      status: s,
    );

HoldingSnapshot snap(
  String id,
  String name,
  int value,
  int asOf, {
  HoldingKind kind = HoldingKind.mutualFund,
  int? invested,
}) =>
    HoldingSnapshot(
      kind: kind,
      name: name,
      identifier: id,
      asOf: asOf,
      valueMinor: value,
      investedMinor: invested,
    );

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  // FR-05-01, FR-05-11, FR-05-19.
  group('statements', () {
    test('insert dedupes by key; locked retries; delete returns file',
        () async {
      final r = StatementRepositoryImpl(env.db);
      final a = await r.insert(stmt('file:abc'));
      expect(a, isA<StatementInserted>());
      expect(await r.insert(stmt('file:abc')), isA<StatementAlreadyImported>());
      final l = await r.insert(stmt('m1#pdf0', s: StatementStatus.locked));
      expect(await r.insert(stmt('m1#pdf0')), isA<StatementRetryLocked>());
      final id = (l as StatementInserted).statement.id;
      expect(await r.locked(), hasLength(1));
      expect(await r.watchLockedCount().first, 1);

      await r.markProcessed(
        id,
        status: StatementStatus.parsed,
        at: 99,
        kind: StatementKind.creditCard,
        bankName: 'HDFC Bank',
        last4: '5678',
        transactionCount: 4,
        filePath: '/f/x.pdf',
        totals: const StatementTotals(totalDueMinor: 123400, dueEpochDay: 5),
      );
      final s = (await r.byId(id))!;
      expect(s.status, StatementStatus.parsed);
      expect(s.kind, StatementKind.creditCard);
      expect(s.totals.totalDueMinor, 123400);
      expect(s.sender, 'me');
      expect(await r.locked(), isEmpty);
      expect(await r.delete(id), '/f/x.pdf');
      expect(await r.byKey('m1#pdf0'), isNull);
    });

    test('markLocked caps email text at 4000', () async {
      final r = StatementRepositoryImpl(env.db);
      final id =
          ((await r.insert(stmt('k'))) as StatementInserted).statement.id;
      await r.markLocked(id, at: 5, emailText: 'x' * 5000);
      final s = (await r.byId(id))!;
      expect(s.isLocked, isTrue);
      expect(s.emailText!.length, 4000);
    });
  });

  // FR-16-09, FR-16-17, FR-16-18.
  group('holdings', () {
    test('newer replaces older and keeps previous; older is ignored', () async {
      final r = HoldingRepositoryImpl(env.db, now: () => 1);
      await r.record(
        [snap('INF1', 'A Fund', 100000, 100, invested: 80000)],
        HoldingSource.statement,
      );
      await r.record([snap('INF1', 'A Fund', 120000, 200)], HoldingSource.sms);
      var h = (await r.list()).single;
      expect(h.valueMinor, 120000);
      expect(h.investedMinor, 80000);
      expect(h.previousValueMinor, 100000);
      expect(h.previousAsOf, 100);
      expect(h.source, HoldingSource.sms);
      await r.record([snap('INF1', 'A Fund', 5, 150)], HoldingSource.sms);
      h = (await r.list()).single;
      expect(h.valueMinor, 120000);
    });

    test('EPF ids merge across sources; manual rows never matched', () async {
      final r = HoldingRepositoryImpl(env.db);
      await r.record(
        [
          snap(
            'EPF:MH/BAN/0012345/000/0001234',
            'EPF',
            25625000,
            100,
            kind: HoldingKind.epf,
          ),
        ],
        HoldingSource.sms,
      );
      await r.record(
        [
          snap(
            'EPF:MHBAN00123450000001234',
            'EPF passbook',
            26000000,
            200,
            kind: HoldingKind.epf,
          ),
        ],
        HoldingSource.statement,
      );
      expect(await r.list(), hasLength(1));
      final m = await r.addManual(
        kind: HoldingKind.mutualFund,
        name: 'Parag Parikh Flexi Cap',
        valueMinor: 5,
        at: 1,
      );
      await r.record(
        [
          snap('MF:PARAG PARIKH FLEXI CAP', 'Parag Parikh Flexi Cap', 9, 5),
        ],
        HoldingSource.statement,
      );
      expect(await r.list(), hasLength(3));
      expect((await r.byId(m))!.isManual, isTrue);
    });

    test('ISIN holding absorbs a same-fund name row', () async {
      final r = HoldingRepositoryImpl(env.db);
      await r.record(
        [
          snap(
            'INF879O01027',
            'Parag Parikh Flexi Cap Fund Direct Growth',
            100,
            100,
          ),
        ],
        HoldingSource.statement,
      );
      await r.record(
        [
          snap(
            'MF:PPFAS FLEXI',
            'PPFAS Mutual Fund - Parag Parikh Flexi Cap',
            110,
            200,
          ),
        ],
        HoldingSource.email,
      );
      final one = await r.list();
      expect(one, hasLength(1));
      expect(one.single.identifier, 'INF879O01027');
    });

    test('aggregates are skipped when covered and dropped by dedupe', () async {
      final r = HoldingRepositoryImpl(env.db);
      await r.record(
        [
          snap('AGG:INDMONEY:MF', 'INDmoney MF', 500, 100),
        ],
        HoldingSource.email,
      );
      expect(await r.list(), hasLength(1));
      await r.record(
        [snap('INF1', 'Some Fund', 10, 200)],
        HoldingSource.statement,
      );
      expect((await r.list()).map((h) => h.identifier), ['INF1']);
      await r.record(
        [
          snap('AGG:INDMONEY:MF', 'INDmoney MF', 500, 300),
        ],
        HoldingSource.email,
      );
      expect(await r.list(), hasLength(1));
    });

    test('manual add, edit, delete', () async {
      final r = HoldingRepositoryImpl(env.db);
      final id = await r.addManual(
        kind: HoldingKind.gold,
        name: 'Gold',
        valueMinor: 100,
        at: 1,
      );
      await r.edit(
        id,
        kind: HoldingKind.gold,
        name: 'Gold',
        valueMinor: 150,
        at: 2,
      );
      final h = (await r.byId(id))!;
      expect(h.identifier, startsWith('manual:'));
      expect(h.valueMinor, 150);
      expect(h.previousValueMinor, 100);
      await r.delete(id);
      expect(await r.list(), isEmpty);
    });
  });

  // FR-16-02, FR-16-03 (worked example 1).
  test('portfolio summary and allocation in paise', () {
    Holding h(HoldingKind k, int v, int? inv) => Holding(
          id: 1,
          kind: k,
          name: 'n',
          identifier: '$k$v',
          source: HoldingSource.statement,
          updatedAt: 0,
          valueMinor: v,
          investedMinor: inv,
        );
    final s = summarisePortfolio([
      h(HoldingKind.mutualFund, 12000000, 10000000),
      h(HoldingKind.stock, 5000000, 4000000),
      h(HoldingKind.epf, 25625000, null),
    ]);
    expect(s.valueMinor, 42625000);
    expect(s.investedMinor, 14000000);
    expect(s.gainMinor, 3000000);
    expect(s.returnPct, closeTo(21.43, 0.01));
    expect(s.byClass[AssetClass.equity], 17000000);
    expect(s.byClass[AssetClass.retirement], 25625000);
  });

  // FR-16-04 (worked example 2), FR-16-05.
  group('net worth', () {
    Account acct(
      int id,
      AccountType t, {
      AccountUsage u = AccountUsage.personal,
    }) =>
        Account(
          id: id,
          bankName: 'B',
          last4: '000$id',
          kind: AccountKind.account,
          createdAt: 0,
          accountType: t,
          usage: u,
        );
    AccountWithActivity act(Account a, int bal) => AccountWithActivity(
          account: Account(
            id: a.id,
            bankName: a.bankName,
            last4: a.last4,
            kind: a.kind,
            createdAt: 0,
            accountType: a.accountType,
            usage: a.usage,
            latestBalanceMinor: bal,
            balanceUpdatedAt: 1,
          ),
          changeSinceManual: 0,
          changeSinceReported: 0,
          monthSpent: 0,
          transactionCount: 0,
        );
    final accounts = [
      act(acct(1, AccountType.savings), 8000000),
      act(acct(2, AccountType.fd), 20000000),
      act(acct(3, AccountType.loan), -30000000),
      act(acct(4, AccountType.current, u: AccountUsage.business), 1000000),
    ];
    final holdings = [
      const Holding(
        id: 1,
        kind: HoldingKind.mutualFund,
        name: 'F',
        identifier: 'INF1',
        source: HoldingSource.statement,
        updatedAt: 0,
        valueMinor: 42625000,
      ),
    ];
    final cards = [
      const CardLimit(
        id: 9,
        name: 'c',
        bankName: 'HDFC',
        last4: '1',
        position: CardPosition(billedMinor: 1234500),
        paid: false,
      ),
    ];

    test('assets minus liabilities, exclusions, books', () {
      final w = computeNetWorth(
        accounts: accounts,
        holdings: holdings,
        cards: cards,
      );
      expect(w.assetsMinor, 8000000 + 1000000 + 20000000 + 42625000);
      expect(w.liabilitiesMinor, 30000000 + 1234500);
      expect(w.netMinor, w.assetsMinor - w.liabilitiesMinor);
      final noDues = computeNetWorth(
        accounts: accounts,
        holdings: holdings,
        cards: cards,
        filter: const NetWorthFilter(
          excludedLiabilities: {LiabilityKind.cardDues},
        ),
      );
      expect(noDues.liabilitiesMinor, 30000000);
      final personal = computeNetWorth(
        accounts: accounts,
        holdings: holdings,
        cards: cards,
        book: Book.personal,
      );
      expect(personal.assetsMinor, w.assetsMinor - 1000000);
      final business = computeNetWorth(
        accounts: accounts,
        holdings: holdings,
        cards: cards,
        book: Book.business,
      );
      expect(business.assetsMinor, w.assetsMinor - 42625000);
      final noEquity = computeNetWorth(
        accounts: accounts,
        holdings: holdings,
        cards: cards,
        filter: const NetWorthFilter(excludedClasses: {AssetClass.equity}),
      );
      expect(noEquity.assetsMinor, w.assetsMinor - 42625000);
      final noAcct = computeNetWorth(
        accounts: accounts,
        holdings: holdings,
        cards: cards,
        filter: const NetWorthFilter(excludedAccountIds: {1}),
      );
      expect(noAcct.assetsMinor, w.assetsMinor - 8000000);
    });

    test('records one point per day and only on change', () async {
      final r = NetWorthRepositoryImpl(env.db);
      expect(await r.recordPoint(100, 0, 0), isFalse);
      expect(await r.recordPoint(100, 500, 100), isTrue);
      expect(await r.recordPoint(100, 500, 100), isFalse);
      expect(await r.recordPoint(100, 600, 100), isTrue);
      expect(await r.recordPoint(101, 700, 0), isTrue);
      final pts = await r.points();
      expect(pts.map((p) => p.assetsMinor), [600, 700]);
      expect(await r.points(sinceDay: 101), hasLength(1));
    });

    test('keeps the last 1100 points', () async {
      final r = NetWorthRepositoryImpl(env.db);
      for (var d = 0; d < 1105; d++) {
        await r.recordPoint(d, d + 1, 0);
      }
      final pts = await r.points();
      expect(pts, hasLength(1100));
      expect(pts.first.day, 5);
    });

    test('prefs persist', () async {
      final p = NetWorthPrefsRepositoryImpl(env.settings);
      await p.save(
        const NetWorthFilter(
          excludedClasses: {AssetClass.gold},
          excludedLiabilities: {LiabilityKind.loans},
          excludedAccountIds: {3},
        ),
      );
      final f = await p.read();
      expect(f.excludedClasses, {AssetClass.gold});
      expect(f.excludedLiabilities, {LiabilityKind.loans});
      expect(f.excludedAccountIds, {3});
      expect(f.isDefault, isFalse);
    });
  });

  // FR-14-06..09.
  group('card dues', () {
    test('notices dedupe by key; total replaces a totalless row', () async {
      final r = CardDueRepositoryImpl(env.db);
      NewCardNotice due({int? total}) => NewCardNotice(
            isPayment: false,
            source: CardDueSource.sms,
            receivedAt: 1,
            processedAt: 1,
            bankName: 'HDFC Bank',
            last4: '5678',
            totalDueMinor: total,
            statementEpochDay: 10,
          );
      expect(await r.recordNotice(due()), isTrue);
      expect(await r.recordNotice(due(total: 500)), isTrue);
      expect(await r.recordNotice(due(total: 900)), isFalse);
      expect(await r.recordNotice(due()), isFalse);
      const pay = NewCardNotice(
        isPayment: true,
        source: CardDueSource.sms,
        receivedAt: 1,
        processedAt: 1,
        bankName: 'HDFC Bank',
        last4: '5678',
        statementEpochDay: 12,
        paymentMinor: 100,
      );
      expect(await r.recordNotice(pay), isTrue);
      expect(await r.recordNotice(pay), isFalse);
      final rows = await r.notices();
      expect(rows, hasLength(2));
      expect(rows.firstWhere((x) => !x.isPayment).totalDueMinor, 500);
    });

    test('service derives a card, mark paid clears override and is undoable',
        () async {
      env.clock = ms(2026, 10, 12);
      final id = (await env.accounts.create(
        const NewAccount(
          kind: AccountKind.card,
          bankName: 'HDFC Bank',
          last4: '5678',
          accountType: AccountType.creditCard,
        ),
      ))!;
      final dues = CardDueRepositoryImpl(env.db);
      final paid = CardPaidStoreImpl(env.settings);
      await dues.recordNotice(
        NewCardNotice(
          isPayment: false,
          source: CardDueSource.sms,
          receivedAt: ms(2026, 10, 6),
          processedAt: ms(2026, 10, 6),
          bankName: 'HDFC',
          last4: '5678',
          totalDueMinor: 1234500,
          minDueMinor: 62000,
          dueEpochDay: CardDay.fromYmd(2026, 10, 24),
          statementEpochDay: CardDay.fromYmd(2026, 10, 5),
        ),
      );
      final svc = CardDueService(
        accounts: env.accounts,
        dues: dues,
        statements: StatementRepositoryImpl(env.db),
        flow: CardFlowSourceImpl(env.txs),
        paid: paid,
        now: () => env.clock,
      );
      final c = (await svc.card(id))!;
      expect(c.billedMinor, 1234500);
      expect(c.minDueMinor, 62000);
      expect(c.paid, isFalse);
      expect(c.owedMinor, 1234500);

      final actions =
          CardDueActions(dues: dues, paid: paid, now: () => ms(2026, 10, 12));
      await actions.saveEdit(c, calculated: c.position, billedMinor: 900000);
      expect((await svc.card(id))!.billedMinor, 900000);
      // Equal-to-calculated values are not stored.
      await actions.saveEdit(c, calculated: c.position, billedMinor: 1234500);
      expect(await dues.overrideFor('hdfc bank:5678'), isNull);

      await actions.saveEdit(c, calculated: c.position, billedMinor: 900000);
      await actions.markPaid(c);
      final after = (await svc.card(id))!;
      expect(after.paid, isTrue);
      expect(after.position.edited, isFalse);
      await actions.undoPaid(after);
      expect((await svc.card(id))!.paid, isFalse);
      expect(await env.count('transactions'), 0);
    });
  });

  // FR-27-13, FR-27-16, FR-27-17, FR-05-09, FR-05-10.
  group('profile and passwords', () {
    test('bank identity store seals per account with limits', () async {
      final s = BankIdentityStore(MemSecure());
      await s.save(
        const BankIdentity(
          accountId: 3,
          customerId: 'ab-12 34',
          ifsc: 'hdfc0001234567',
        ),
      );
      final b = (await s.read(3))!;
      expect(b.customerId, 'ab1234');
      expect(b.ifsc, 'HDFC0001234');
      expect(await s.readAll(), hasLength(1));
      await s.save(const BankIdentity(accountId: 3));
      expect(await s.read(3), isNull);
    });

    test('saved passwords replace by label', () async {
      final s = StatementPasswordStore(MemSecure());
      await s.add(const SavedPassword(label: 'HDFC', secret: 'a'));
      await s.add(const SavedPassword(label: 'HDFC', secret: 'b'));
      await s.add(const SavedPassword(label: 'AXIS', secret: 'c'));
      expect((await s.list()).map((p) => p.secret), ['b', 'c']);
      await s.remove('HDFC');
      expect((await s.list()).single.label, 'AXIS');
    });

    test('password source applies profile fallback', () {
      final src = assemblePasswordSource(
        identity: Identity(name: 'Rahul Sharma', dob: DateTime(1990, 5)),
        profile: const UserProfile(phone: '9876543210'),
        cardLast4s: ['5678', '56', '5678'],
        banks: const [
          BankIdentity(accountId: 1, customerId: 'C1'),
          BankIdentity(accountId: 2),
        ],
        saved: ['pw', ''],
      );
      expect(src.cardLast4s, {'5678'});
      expect(src.banks, hasLength(1));
      expect(src.banks.single.name, 'Rahul Sharma');
      expect(src.banks.single.mobile, '9876543210');
      expect(src.saved, ['pw']);
      expect(src.hasBankDetails, isTrue);
    });

    test('own numbers and profile draft', () {
      expect(
        ownLast4s(['+91 98765 43210', '12345', null, '9000011111']),
        {'3210', '1111'},
      );
      expect(
        const ProfileDraft(name: 'A', pan: 'ABCDE1234F', dirty: true).canSave,
        isTrue,
      );
      expect(
        const ProfileDraft(name: 'A', pan: 'BAD', dirty: true).canSave,
        isFalse,
      );
      expect(
        const ProfileDraft(name: ' ', pan: '', dirty: true).canSave,
        isFalse,
      );
      expect(
        const ProfileDraft(name: 'A', pan: '', dirty: false).canSave,
        isFalse,
      );
    });
  });
}

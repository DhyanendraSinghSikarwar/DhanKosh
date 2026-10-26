import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/backup_export/data/backup_crypto.dart';
import 'package:hisaab/features/backup_export/data/backup_data.dart';
import 'package:hisaab/features/backup_export/data/full_backup_service.dart';
import 'package:hisaab/features/backup_export/domain/backup_errors.dart';
import 'package:hisaab/features/backup_export/domain/passphrase_strength.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_paid_store_impl.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/expense_tracking/data/budget_repository_impl.dart';
import 'package:hisaab/features/forex_rates/data/forex_repository_impl.dart';
import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';
import 'package:hisaab/features/loans/data/loan_account_repository_impl.dart';
import 'package:hisaab/features/loans/data/loan_link_repository_impl.dart';
import 'package:hisaab/features/loans/domain/loan_account_repository.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/recurring_transactions/data/recurring_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/data/sip_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';
import 'package:hisaab/features/savings_goals/data/goal_repository_impl.dart';
import 'package:hisaab/features/savings_goals/domain/goal.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/transactions_ledger/data/data_reset_repository_impl.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:parser_core/parser_core.dart' hide HoldingKind;

import '../../support/parsed.dart';
import '../../support/test_env.dart';

BackupData dataOf(TestEnv e) => BackupData(
      BackupDeps(
        txs: e.txs,
        accounts: e.accounts,
        loans: LoanAccountRepositoryImpl(e.db, now: () => e.clock),
        categories: e.categories,
        budgets: BudgetRepositoryImpl(e.db),
        recurring: RecurringRepositoryImpl(e.db),
        holdings: HoldingRepositoryImpl(e.db),
        cards: CardDueRepositoryImpl(e.db),
        cardPaid: CardPaidStoreImpl(e.settings),
        loanLinks: LoanLinkRepositoryImpl(e.db),
        forex: ForexRepositoryImpl(e.db),
        sips: SipRepositoryImpl(e.db),
        goals: GoalRepositoryImpl(e.db),
        settings: e.settings,
        reset: DataResetRepositoryImpl(e.db),
      ),
    );

FullBackupService svcOf(TestEnv e) => FullBackupService(
      dataOf(e),
      (ms) => e.settings.write(lastFullBackupKey, ms),
      iterations: BackupCrypto.minIterations,
    );

Future<void> seed(TestEnv e) async {
  await e.ingest(parsed(ref: 'r1', balance: 900000));
  await e.ingest(
    parsed(
      amountMinor: 120000,
      merchant: 'Big Bazaar',
      ref: 'r2',
      time: t0 + 2 * hour,
      category: Category.groceries,
    ),
  );
  await e.ingest(
    parsed(
      amountMinor: 5000000,
      type: TransactionType.credit,
      merchant: 'Acme Payroll',
      ref: 'r3',
      time: t0 + 5 * hour,
      category: Category.salary,
    ),
  );
  await e.categories.saveManualRule(
    const MerchantRule(
      merchantKey: 'swiggy',
      category: Category.food,
      updatedAt: 5,
      matchType: RuleMatch.contains,
      manual: true,
    ),
  );
  final d = dataOf(e);
  await d.restore({
    'format': backupFormat,
    'schema': 1,
    'budgets': [
      {'category': 'FOOD', 'limit': 400000},
    ],
    'holdings': [
      {
        'kind': 'MUTUAL_FUND',
        'name': 'Test Fund',
        'identifier': 'manual:abc',
        'units': 12.5,
        'value': 1500000,
        'invested': 1200000,
        'asOf': t0,
        'source': 'MANUAL',
      },
    ],
    'recurring': [
      {
        'name': 'Rent',
        'amount': 2500000,
        'income': false,
        'freq': 'MONTHLY',
        'day': 5,
        'category': 'RENT',
      },
    ],
    'forex': [
      {'currency': 'USD', 'day': 20000, 'rate': 83.5},
    ],
    'cardOverrides': [
      {'cardKey': 'hdfc bank:1234', 'setAt': t0, 'billed': 1000},
    ],
    'loans': [
      {
        'bank': 'Test Bank',
        'last4': '9999',
        'principal': 100000000,
        'rate': 900,
        'tenure': 120,
        'startDay': 5,
        'outstanding': 90000000,
      },
    ],
    'settings': {'history_days': 45},
  });
}

Future<List<Object?>> fingerprint(TestEnv e) async {
  final d = dataOf(e);
  final doc = await d.collect(now: 0);
  final txs = [
    for (final t in doc['transactions']! as List<Object?>)
      {...(t! as Map<String, Object?>)}..remove('sources'),
  ];
  return [
    txs,
    doc['rules'],
    doc['budgets'],
    doc['holdings'],
    doc['recurring'],
    doc['forex'],
    doc['cardOverrides'],
    doc['loans'],
    (doc['accounts']! as List<Object?>)
        .map((a) => (a! as Map<String, Object?>)['bank'])
        .toList(),
    doc['settings'],
  ];
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('crypto (FR-24-16..20)', () {
    test('round trip, header fields and 200k default', () {
      final f = BackupCrypto.encryptSync(
        '{"a":1}',
        'pass-phrase-1',
        iterations: BackupCrypto.minIterations,
      );
      expect(f.sublist(0, 4), BackupCrypto.magic);
      expect(f[4], BackupCrypto.version);
      expect(BackupCrypto.defaultIterations, greaterThanOrEqualTo(200000));
      expect(BackupCrypto.decryptSync(f, 'pass-phrase-1'), '{"a":1}');
    });

    test('two encryptions of the same data differ (salt and nonce)', () {
      final a =
          BackupCrypto.encryptSync('x', 'pass-phrase-1', iterations: 1000);
      final b =
          BackupCrypto.encryptSync('x', 'pass-phrase-1', iterations: 1000);
      expect(a, isNot(b));
    });

    test('wrong passphrase gives a clear error', () {
      final f =
          BackupCrypto.encryptSync('{}', 'right-pass-1', iterations: 1000);
      expect(
        () => BackupCrypto.decryptSync(f, 'wrong-pass-1'),
        throwsA(isA<BackupAuthException>()),
      );
    });

    test('tampered body or header fails; never partial', () {
      final f =
          BackupCrypto.encryptSync('{}', 'right-pass-1', iterations: 1000);
      for (final i in [f.length - 1, 40, 12, 30]) {
        final t = Uint8List.fromList(f)..[i] ^= 1;
        expect(
          () => BackupCrypto.decryptSync(t, 'right-pass-1'),
          throwsA(isA<BackupAuthException>()),
          reason: 'byte $i',
        );
      }
    });

    test('not a backup / newer version', () {
      expect(
        () => BackupCrypto.decryptSync(Uint8List(80), 'x'),
        throwsA(isA<BackupFormatException>()),
      );
      final f =
          BackupCrypto.encryptSync('{}', 'right-pass-1', iterations: 1000);
      final newer = Uint8List.fromList(f)..[4] = 9;
      expect(
        () => BackupCrypto.decryptSync(newer, 'right-pass-1'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('passphrase strength hint', () {
      expect(PassphraseStrength.of('abc'), PassphraseStrength.weak);
      expect(PassphraseStrength.of('aaaaaaaaaaaa'), PassphraseStrength.weak);
      expect(PassphraseStrength.of('monsoon22'), PassphraseStrength.fair);
      expect(
        PassphraseStrength.of('Blue-Tiger-Rain-42'),
        PassphraseStrength.strong,
      );
    });
  });

  group('round trip (FR-24-16, FR-24-24)', () {
    test('fresh DB gets identical totals, rules, holdings', () async {
      final a = TestEnv();
      final b = TestEnv();
      addTearDown(a.close);
      addTearDown(b.close);
      await seed(a);
      final before = await fingerprint(a);
      final file = await svcOf(a).build('round-trip-pass', now: DateTime(2026));
      final opened = await svcOf(b).open(file, 'round-trip-pass');
      expect(opened.counts.counts['transactions'], 3);
      final added = await svcOf(b).restore(opened);
      expect(added.counts['transactions'], 3);
      expect(await fingerprint(b), before);
      final totals = await b.txs.watchTotals(fromMs: 0, toMs: t0 * 2).first;
      final totalsA = await a.txs.watchTotals(fromMs: 0, toMs: t0 * 2).first;
      expect(totals.spentMinor, totalsA.spentMinor);
      expect(totals.incomeMinor, totalsA.incomeMinor);
    });

    test('SIPs, goals and MF orders round trip, idempotent (FR-24-32)',
        () async {
      final a = TestEnv();
      final b = TestEnv();
      addTearDown(a.close);
      addTearDown(b.close);
      await SipRepositoryImpl(a.db).add(
        const SipDraft(
          name: 'Axis Bluechip',
          amountMinor: 500000,
          frequency: SipFrequency.monthly,
          startDay: 20000,
          dayOfMonth: 5,
        ),
      );
      final ga = GoalRepositoryImpl(a.db);
      final gid = await ga.addGoal(
        const GoalDraft(name: 'Trip', targetMinor: 9000000, targetDay: 21000),
      );
      await ga.addContribution(gid, 100000, 20100, note: 'first');
      await ga.addContribution(gid, 250000, 20200);
      await ga.addGoal(const GoalDraft(name: 'Bike', targetMinor: 5000000));
      final ha = HoldingRepositoryImpl(a.db);
      await ha.recordMfOrder(
        const MfOrderEntry(
          schemeName: 'Axis Bluechip',
          identifier: 'MF:axis bluechip',
          at: 1760000000000,
          amountMinor: 500000,
          units: 10.5,
          nav: 476.19,
          platform: 'Groww',
        ),
        claimKey: 'm1',
      );
      final file = await svcOf(a).build('round-trip-pass', now: DateTime(2026));
      final svc = svcOf(b);
      final added = await svc.restore(await svc.open(file, 'round-trip-pass'));
      expect(added.counts['SIPs'], 1);
      expect(added.counts['goals'], 2);
      expect(added.counts['MF orders'], 1);
      final sb = await SipRepositoryImpl(b.db).watchAll().first;
      expect(sb.single.name, 'Axis Bluechip');
      expect(sb.single.dayOfMonth, 5);
      final gb = GoalRepositoryImpl(b.db);
      final goals = await gb.watchGoals().first;
      expect(goals.map((g) => g.name), ['Trip', 'Bike']);
      expect(goals.first.targetDay, 21000);
      final cs = await gb.watchContributions().first;
      expect(cs.map((c) => c.amountMinor), [100000, 250000]);
      expect(cs.first.note, 'first');
      final hb = HoldingRepositoryImpl(b.db);
      final orders = await hb.watchMfOrders().first;
      expect(orders.single.units, 10.5);
      expect(orders.single.platform, 'Groww');
      // The claim blocks the same purchase arriving again by mail.
      expect(
        await hb.recordMfOrder(orders.single, claimKey: 'other'),
        isFalse,
      );
      final again = await svc.restore(await svc.open(file, 'round-trip-pass'));
      expect(again.total, 0);
      expect((await gb.watchContributions().first).length, 2);
    });

    test('older backup without the new sections still restores', () async {
      final a = TestEnv();
      addTearDown(a.close);
      final added = await dataOf(a).restore({
        'format': backupFormat,
        'schema': 1,
        'budgets': [
          {'category': 'FOOD', 'limit': 100000},
        ],
      });
      expect(added.counts['budgets'], 1);
      expect(added.counts['SIPs'], 0);
      expect(added.counts['goals'], 0);
      expect(added.counts['MF orders'], 0);
    });

    test('restoring onto existing data adds nothing twice', () async {
      final a = TestEnv();
      addTearDown(a.close);
      await seed(a);
      final svc = svcOf(a);
      final file = await svc.build('round-trip-pass', now: DateTime(2026));
      final before = await fingerprint(a);
      final again = await svc.restore(
        await svc.open(file, 'round-trip-pass'),
      );
      expect(again.counts['transactions'], 0);
      expect(again.total, 0);
      expect(await fingerprint(a), before);
      expect(await a.count('transactions'), 3);
    });

    test('replace erases first and restores the backup', () async {
      final a = TestEnv();
      final b = TestEnv();
      addTearDown(a.close);
      addTearDown(b.close);
      await seed(a);
      await b.ingest(parsed(amountMinor: 777, ref: 'zz', merchant: 'Other'));
      final svc = svcOf(b);
      final file = await svcOf(a).build('round-trip-pass', now: DateTime(2026));
      await svc.restore(await svc.open(file, 'round-trip-pass'), replace: true);
      expect(await b.count('transactions'), 3);
      expect(await fingerprint(b), await fingerprint(a));
    });

    test('wrong passphrase imports nothing', () async {
      final a = TestEnv();
      final b = TestEnv();
      addTearDown(a.close);
      addTearDown(b.close);
      await seed(a);
      final file = await svcOf(a).build('round-trip-pass', now: DateTime(2026));
      await expectLater(
        svcOf(b).open(file, 'nope-nope-nope'),
        throwsA(isA<BackupAuthException>()),
      );
      expect(await b.count('transactions'), 0);
    });

    test('secrets and lock state are not in the document', () async {
      final a = TestEnv();
      addTearDown(a.close);
      await seed(a);
      await a.settings.write(const SettingKey<bool>('app_lock', false), true);
      await a.settings.write(
        const SettingKey<String>('email_password', ''),
        'hunter2',
      );
      final doc = await dataOf(a).collect(now: 0);
      final keys = (doc['settings']! as Map).keys.toSet();
      expect(keys, isNot(contains('app_lock')));
      expect(keys, isNot(contains('email_password')));
      expect(doc.toString(), isNot(contains('hunter2')));
    });

    test('short passphrase is refused', () async {
      final a = TestEnv();
      addTearDown(a.close);
      await expectLater(
        svcOf(a).build('short', now: DateTime(2026)),
        throwsFormatException,
      );
    });

    test('review rows and sources survive', () async {
      final a = TestEnv();
      final b = TestEnv();
      addTearDown(a.close);
      addTearDown(b.close);
      await a.ingest(parsed(ref: 'k1'), id: 'sms-1', raw: 'masked body');
      await a.ingest(
        parsed(source: Source.email, ref: 'k1'),
        id: 'mail-1',
      );
      final file = await svcOf(a).build('round-trip-pass', now: DateTime(2026));
      await svcOf(b).restore(await svcOf(b).open(file, 'round-trip-pass'));
      final rows = await b.txs.watch(const LedgerFilter()).first;
      expect(rows, hasLength(1));
      final src = await b.txs.sourcesOf(rows.single.id);
      expect(src.map((s) => s.sourceMessageId).toSet(), {'sms-1', 'mail-1'});
    });
  });

  test('model types used by the fixtures compile', () {
    expect(HoldingKind.values, isNotEmpty);
    expect(const ForexRate(currency: 'USD', day: 1, inrPerUnit: 1).day, 1);
    expect(const CardOverride(cardKey: 'a', setAt: 0).cardKey, 'a');
    expect(
      const LoanDraft(
        bankName: 'b',
        principalMinor: 1,
        rateBps: 1,
        tenureMonths: 1,
      ).bankName,
      'b',
    );
    expect(
      const RecurringDraft(
        name: 'n',
        amountMinor: 1,
        frequency: RecurringFrequency.monthly,
        dayOfMonth: 1,
        category: Category.other,
      ).name,
      'n',
    );
  });
}

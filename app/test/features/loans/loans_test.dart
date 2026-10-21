import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/loans/domain/amortization.dart';
import 'package:hisaab/features/loans/domain/emi_pairing.dart';
import 'package:hisaab/features/loans/domain/loan_builder.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

var _n = 0;

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

LedgerTx tx(
  DateTime date,
  int amount, {
  required int accountId,
  String? merchant,
  Category category = Category.emiLoan,
  Channel channel = Channel.other,
  bool needsReview = false,
  String currency = 'INR',
  TransactionType type = TransactionType.debit,
  int? customCategoryId,
  String? note,
}) {
  _n++;
  return LedgerTx(
    id: _n,
    amountMinor: amount,
    currency: currency,
    type: type,
    bankName: 'HDFC Bank',
    accountLast4: '1234',
    accountKind: AccountKind.account,
    accountId: accountId,
    merchant: merchant,
    channel: channel,
    timestamp: epochMsOf(date, hour: 10),
    hasExplicitTime: true,
    category: category,
    transactionHash: 'h$_n',
    confidence: 1,
    needsReview: needsReview,
    createdAt: 0,
    customCategoryId: customCategoryId,
    note: note,
  );
}

LoanAccount loanAcc(int id, String bank, {String last4 = '', int? bal}) =>
    LoanAccount(id: id, bankName: bank, last4: last4, currentBalanceMinor: bal);

void main() {
  final today = d(2026, 10, 20);

  group('Amortization (FR-15-05, TC-15-01)', () {
    test('emi matches the reducing-balance formula', () {
      expect(Amortization.emi(100000000, 850, 240), 867823);
      expect(Amortization.emi(10000000, 1200, 12), 888488);
      expect(Amortization.emi(12000000, 0, 12), 1000000);
      expect(Amortization.emi(0, 850, 12), 0);
      expect(Amortization.emi(100, 0, 3), 34); // ceil
    });

    test('memory worked example 1: 5,00,000 at 10.5% for 60 months', () {
      final emi = Amortization.emi(50000000, 1050, 60);
      expect(emi, closeTo(1074700, 100)); // about 10,747
      final s = Amortization.schedule(
        const LoanTerms(
          principalMinor: 50000000,
          rateBps: 1050,
          tenureMonths: 60,
        ),
      );
      expect(s.first.interestMinor, 437500);
      expect(s.first.principalMinor, s.first.emiMinor - 437500);
    });

    test('schedule splits interest and principal and ends at zero', () {
      final terms = LoanTerms(
        principalMinor: 100000000,
        rateBps: 850,
        tenureMonths: 240,
        startDay: d(2025, 1, 5),
      );
      final s = Amortization.schedule(terms);
      expect(s.length, 240);
      expect(s.first.interestMinor, 708333);
      expect(s.first.principalMinor, 159490);
      expect(s.last.balanceAfterMinor, 0);
      expect(s.fold<int>(0, (a, e) => a + e.principalMinor), 100000000);
      expect(s.fold<int>(0, (a, e) => a + e.interestMinor), 108277663);
      expect(s[1].due, d(2025, 2, 5));
      for (var i = 1; i < s.length; i++) {
        expect(s[i].interestMinor <= s[i - 1].interestMinor, isTrue);
      }
      // Reconciles to the paisa: sum of EMIs == principal + interest.
      expect(
        s.fold<int>(0, (a, e) => a + e.emiMinor),
        100000000 + 108277663,
      );
    });

    test('zero rate schedule ends at tenure; EMI override pays off early', () {
      final s = Amortization.schedule(
        const LoanTerms(principalMinor: 12000000, rateBps: 0, tenureMonths: 12),
      );
      expect(s.length, 12);
      expect(s.every((e) => e.interestMinor == 0), isTrue);
      expect(s.last.balanceAfterMinor, 0);
      final big = Amortization.schedule(
        const LoanTerms(principalMinor: 5000000, rateBps: 0, tenureMonths: 24),
        emiMinor: 2000000,
      );
      expect(big.map((e) => e.emiMinor), [2000000, 2000000, 1000000]);
    });

    test('too-small EMI is capped and never loops for ever', () {
      final s = Amortization.schedule(
        const LoanTerms(
          principalMinor: 100000000,
          rateBps: 850,
          tenureMonths: 12,
        ),
        emiMinor: 100000,
      );
      expect(s, isEmpty); // principal part <= 0 stops it
      final slow = Amortization.schedule(
        const LoanTerms(
          principalMinor: 1000000,
          rateBps: 0,
          tenureMonths: 1000,
        ),
        emiMinor: 1,
      );
      expect(slow.length, 1000); // n == tenure is the last instalment
    });

    test('elapsed, dueOn clamp and remainingEmis agree with the schedule', () {
      final first = d(2025, 1, 31);
      expect(Amortization.elapsed(first, d(2025, 1, 30), 240), 0);
      expect(Amortization.elapsed(first, d(2025, 1, 31), 240), 1);
      expect(Amortization.elapsed(first, d(2025, 2, 28), 240), 2);
      expect(Amortization.dueOn(first, 2), d(2025, 2, 28));
      expect(Amortization.elapsed(first, d(2040, 1, 1), 12), 12);
      final s = Amortization.schedule(
        LoanTerms(
          principalMinor: 100000000,
          rateBps: 850,
          tenureMonths: 240,
          startDay: first,
        ),
      );
      final after60 = s[59].balanceAfterMinor;
      expect(Amortization.remainingEmis(after60, 867823, 850), 180);
      expect(Amortization.remainingEmis(0, 867823, 850), 0);
      expect(Amortization.remainingEmis(100000000, 100000, 850), isNull);
      expect(Amortization.remainingEmis(100000000, 0, 850), isNull);
      expect(Amortization.remainingEmis(1000, 300, 0), 4);
    });

    test('principal and interest split of paid instalments', () {
      final s = Amortization.schedule(
        const LoanTerms(
          principalMinor: 12000000,
          rateBps: 1200,
          tenureMonths: 12,
        ),
      );
      final p = Amortization.splitPaid(s, 3);
      expect(
        p.principalMinor + p.interestMinor,
        s.take(3).fold<int>(0, (a, e) => a + e.emiMinor),
      );
    });

    test('prepayment tag above 120% of the EMI (worked example 4)', () {
      expect(Amortization.isPrepayment(2500000, 1234500), isTrue);
      expect(Amortization.isPrepayment(1481401, 1234500), isTrue);
      expect(Amortization.isPrepayment(1481400, 1234500), isFalse);
      expect(Amortization.isPrepayment(100, null), isFalse);
    });
  });

  group('Loans.build (FR-15-01..04, TC-15-02..04)', () {
    test('a loan account gathers its EMIs and works out what is left', () {
      final loan = LoanAccount(
        id: 7,
        bankName: 'HDFC Bank',
        last4: '4321',
        nickname: 'Home loan',
        principalMinor: 100000000,
        rateBps: 850,
        tenureMonths: 240,
        startDay: epochDayOf(d(2025, 1, 5)),
      );
      final txs = [
        tx(d(2026, 8, 5), 867823, accountId: 7),
        tx(d(2026, 9, 5), 867823, accountId: 7),
        // Same EMI seen on the savings account: counted once.
        tx(d(2026, 9, 6), 867823, accountId: 1, merchant: 'HDFC Bank'),
        tx(d(2026, 10, 5), 867823, accountId: 1, merchant: 'Loan 4321'),
        tx(d(2026, 9, 10), 1200000, accountId: 1, merchant: 'Bajaj Finance'),
        tx(d(2026, 10, 10), 1200000, accountId: 1, merchant: 'Bajaj Finance'),
      ];
      final loans = Loans.build(accounts: [loan], payments: txs, today: today);
      expect(loans.length, 2);
      final home = loans.firstWhere((l) => l.accountId == 7);
      expect(home.key, 'acct:7');
      expect(home.emiMinor, 867823);
      expect(home.emiDay, 5);
      expect(home.trackedCount, 3);
      expect(home.paidCount, 22);
      expect(home.totalEmis, 240);
      expect(home.remainingEmis, 218);
      expect(home.nextDue, d(2026, 11, 5));
      expect(home.payoffDate, d(2044, 12, 5));
      expect(home.payingAccountId, 1);
      expect(home.outstandingSource, OutstandingSource.schedule);
      expect(home.interestPaidMinor! > home.principalPaidMinor!, isTrue);
      expect(home.upcoming.length, 12);
      expect(home.upcoming.first.number, 23);
      expect(home.closed, isFalse);
      expect(home.progress, inInclusiveRange(0, 1));

      final car = loans.firstWhere((l) => l.detected);
      expect(car.key, 'payee:bajaj finance');
      expect(car.name, 'Bajaj Finance');
      expect(car.emiMinor, 1200000);
      expect(car.nextDue, d(2026, 11, 10));
      expect(car.remainingEmis, isNull);
      expect(car.outstandingSource, OutstandingSource.none);
    });

    test('worked example 2: detected Propelld loan', () {
      final txs = [
        tx(d(2026, 8, 5), 1234500, accountId: 1, merchant: 'Propelld'),
        tx(d(2026, 9, 5), 1234500, accountId: 1, merchant: 'Propelld'),
        tx(d(2026, 10, 5), 1234500, accountId: 1, merchant: 'Propelld'),
      ];
      final l = Loans.build(
        accounts: const [],
        payments: txs,
        today: d(2026, 10, 17),
      ).single;
      expect(l.emiMinor, 1234500);
      expect(l.emiDay, 5);
      expect(l.paidCount, 3);
      expect(l.nextDue, d(2026, 11, 5));
      expect(l.outstandingMinor, isNull);
    });

    test('same-amount copies a day apart count once; prepayment leaves series',
        () {
      final txs = [
        tx(d(2026, 9, 5), 1234500, accountId: 1, merchant: 'Propelld'),
        tx(d(2026, 10, 5), 1234500, accountId: 1, merchant: 'Propelld'),
        tx(d(2026, 10, 6), 1234500, accountId: 1, merchant: 'Propelld'),
        tx(d(2026, 10, 12), 2500000, accountId: 1, merchant: 'Propelld'),
      ];
      final l =
          Loans.build(accounts: const [], payments: txs, today: today).single;
      expect(l.payments.length, 3);
      expect(l.trackedCount, 2);
      expect(l.emiMinor, 1234500);
      expect(Amortization.isPrepayment(2500000, l.emiMinor), isTrue);
    });

    test('detection thresholds (FR-15-03): months, 75 days, dismissed, manual',
        () {
      final one = [
        tx(d(2026, 10, 10), 700000, accountId: 1, merchant: 'Random Payee'),
      ];
      expect(
        Loans.build(accounts: const [], payments: one, today: today),
        isEmpty,
      );
      final manual = Loans.build(
        accounts: const [],
        payments: one,
        today: today,
        links: const LoanLinks(manualPayees: {'random payee'}),
      );
      expect(manual.map((e) => e.key), ['payee:random payee']);

      final two = [
        tx(d(2026, 9, 10), 900000, accountId: 1, merchant: 'Acme Finance'),
        tx(d(2026, 10, 11), 900000, accountId: 1, merchant: 'Acme Finance'),
      ];
      expect(
        Loans.build(accounts: const [], payments: two, today: today).length,
        1,
      );
      expect(
        Loans.build(
          accounts: const [],
          payments: two,
          today: today,
          dismissed: {'acme finance'},
        ),
        isEmpty,
      );
      // Latest payment exactly 75 days old is kept, 76 dropped.
      final t75 = today.subtract(const Duration(days: 75));
      final keep = [
        tx(
          t75.subtract(const Duration(days: 30)),
          900000,
          accountId: 1,
          merchant: 'Old Co',
        ),
        tx(t75, 900000, accountId: 1, merchant: 'Old Co'),
      ];
      expect(
        Loans.build(accounts: const [], payments: keep, today: today).length,
        1,
      );
      final t76 = today.subtract(const Duration(days: 76));
      final drop = [
        tx(
          t76.subtract(const Duration(days: 30)),
          900000,
          accountId: 1,
          merchant: 'Old Co',
        ),
        tx(t76, 900000, accountId: 1, merchant: 'Old Co'),
      ];
      expect(
        Loans.build(accounts: const [], payments: drop, today: today),
        isEmpty,
      );
    });

    test('same month twice is one month; merchant under 2 chars ignored', () {
      final txs = [
        tx(d(2026, 10, 1), 900000, accountId: 1, merchant: 'Acme'),
        tx(d(2026, 10, 15), 800000, accountId: 1, merchant: 'Acme'),
        tx(d(2026, 9, 15), 800000, accountId: 1, merchant: 'X'),
        tx(d(2026, 10, 15), 800000, accountId: 1, merchant: 'X'),
      ];
      expect(
        Loans.build(accounts: const [], payments: txs, today: today),
        isEmpty,
      );
    });

    test(
        'investments, review, non-INR and custom-category rows excluded (FR-15-14)',
        () {
      final txs = [
        for (final m in [d(2026, 9, 10), d(2026, 10, 10)]) ...[
          tx(
            m,
            500000,
            accountId: 1,
            merchant: 'Tata Mutual Fund',
            category: Category.investment,
          ),
          tx(m, 500000, accountId: 1, merchant: 'Review Co', needsReview: true),
          tx(m, 500000, accountId: 1, merchant: 'Dollar Co', currency: 'USD'),
          tx(
            m,
            500000,
            accountId: 1,
            merchant: 'Custom Co',
            customCategoryId: 3,
          ),
          tx(
            m,
            500000,
            accountId: 1,
            merchant: 'Credit Co',
            type: TransactionType.credit,
          ),
          tx(m, 900000, accountId: 1, merchant: 'Acme Finance'),
        ],
      ];
      final l = Loans.build(accounts: const [], payments: txs, today: today);
      expect(l.map((e) => e.key), ['payee:acme finance']);
    });

    test('linked payments and payees count as that loan (FR-15-02, FR-15-10)',
        () {
      final txs = [
        tx(d(2026, 9, 10), 700000, accountId: 1, merchant: 'Random Payee'),
        tx(d(2026, 10, 10), 700000, accountId: 1, merchant: 'Random Payee'),
        tx(d(2026, 10, 12), 300000, accountId: 1, merchant: 'Other Payee'),
      ];
      final acc = [loanAcc(9, 'Muthoot')];
      expect(
        Loans.build(accounts: acc, payments: txs, today: today).first.payments,
        isEmpty,
      );
      final byPayee = Loans.build(
        accounts: acc,
        payments: txs,
        today: today,
        links: const LoanLinks(payee: {'random payee': 9}),
      );
      expect(byPayee.first.payments.length, 2);
      expect(byPayee.where((l) => l.detected), isEmpty);
      final byTx = Loans.build(
        accounts: acc,
        payments: txs,
        today: today,
        links: LoanLinks(tx: {txs[2].id: 9}),
      ).first;
      expect(byTx.payments.map((e) => e.amountMinor), [300000]);
    });

    test('unlinked EMI claimed by last4 text or lender name prefix', () {
      final acc = [loanAcc(9, 'Bajaj Finance', last4: '5678')];
      final txs = [
        tx(d(2026, 10, 10), 700000, accountId: 1, merchant: 'EMI LOAN 5678'),
        tx(
          d(2026, 10, 11),
          300000,
          accountId: 1,
          merchant: 'Bajaj Finance emi',
        ),
        tx(d(2026, 10, 12), 100000, accountId: 1, merchant: 'Bajajx'),
        tx(
          d(2026, 10, 13),
          150000,
          accountId: 1,
          merchant: 'Loan',
          note: 'x 5678 y',
        ),
      ];
      final l = Loans.build(accounts: acc, payments: txs, today: today).first;
      expect(
        l.payments.map((e) => e.amountMinor).toSet(),
        {700000, 300000, 150000},
      );
    });

    test('hidden loan accounts are not listed', () {
      const a = LoanAccount(id: 1, bankName: 'X Bank', hidden: true);
      expect(
        Loans.build(accounts: const [a], payments: const [], today: today),
        isEmpty,
      );
    });

    test('a merged loan counts payments and terms under the target', () {
      final target = loanAcc(1, 'Bajaj Finance');
      final child = LoanAccount(
        id: 2,
        bankName: 'Bajaj Finserv',
        last4: '5555',
        principalMinor: 12000000,
        rateBps: 0,
        tenureMonths: 12,
        startDay: epochDayOf(d(2026, 1, 5)),
        mergedIntoId: 1,
        latestBalanceMinor: -4000000,
        balanceUpdatedAt: 5,
      );
      final txs = [
        tx(d(2026, 9, 5), 1000000, accountId: 2),
        tx(d(2026, 10, 5), 1000000, accountId: 1),
      ];
      final l = Loans.build(
        accounts: [target],
        payments: txs,
        today: today,
        merged: [child],
      );
      expect(l.length, 1);
      expect(l[0].mergedIds, [2]);
      expect(l[0].payments.length, 2);
      expect(l[0].totalEmis, 12);
      expect(l[0].outstandingMinor, 4000000); // child's |balance|
      expect(l[0].outstandingSource, OutstandingSource.bank);
      expect(
        Loans.build(accounts: [target], payments: txs, today: today)
            .first
            .payments
            .length,
        1,
      );
    });

    test('bank outstanding drives remaining; zero outstanding closes the loan',
        () {
      final acc = [loanAcc(3, 'Propelld', bal: -50000)];
      final txs = [
        tx(d(2026, 9, 5), 20000, accountId: 3),
        tx(d(2026, 10, 5), 20000, accountId: 3),
      ];
      final l = Loans.build(accounts: acc, payments: txs, today: today).single;
      expect(l.outstandingMinor, 50000);
      expect(l.remainingEmis, 3); // ceil(50000/20000), zero rate
      expect(l.payoffDate, d(2027, 1, 5));
      expect(l.outstandingSource, OutstandingSource.bank);
      final closed = Loans.build(
        accounts: [loanAcc(3, 'Propelld', bal: 0)],
        payments: txs,
        today: today,
      ).single;
      expect(closed.closed, isTrue);
      expect(closed.nextDue, isNull);
    });

    test(
        'nextDue: not yet paid this month vs already paid; clamps to month end',
        () {
      final a = [
        tx(d(2026, 8, 31), 500000, accountId: 1, merchant: 'Month End Co'),
        tx(d(2026, 9, 30), 500000, accountId: 1, merchant: 'Month End Co'),
      ];
      final l =
          Loans.build(accounts: const [], payments: a, today: d(2026, 10, 20))
              .single;
      expect(l.emiDay, 31);
      expect(l.nextDue, d(2026, 10, 31));
      final s =
          Loans.build(accounts: const [], payments: a, today: d(2026, 11, 1))
              .single;
      expect(s.nextDue, d(2026, 11, 30));
    });

    test('loans sort by outstanding desc, detected by next due', () {
      final acc = [
        loanAcc(1, 'A Bank', bal: -100),
        loanAcc(2, 'B Bank', bal: -300),
        loanAcc(3, 'C Bank', bal: -200),
      ];
      final l = Loans.build(accounts: acc, payments: const [], today: today);
      expect(l.map((e) => e.accountId), [2, 3, 1]);
    });
  });

  group('Duplicates (FR-15-12, TC-15-05)', () {
    test('likely duplicate loans are suggested', () {
      final a = Loans.build(
        accounts: [
          loanAcc(1, 'Bajaj Finance', last4: '1234'),
          loanAcc(2, 'Bajaj Finance Ltd'),
          loanAcc(3, 'HDFC Bank', last4: '9999'),
          loanAcc(4, 'Tata Capital', last4: '9999'),
        ],
        payments: const [],
        today: today,
      );
      final dups = Loans.duplicates(a);
      expect(dups.map((e) => e.key).toSet(), {'1-2', '3-4'});
      expect(
        Loans.duplicates(a, ignored: {'1-2'}).map((e) => e.key),
        ['3-4'],
      );
    });

    test(
        'different last4 or no name overlap is not a duplicate; into has terms',
        () {
      final a = Loans.build(
        accounts: [
          loanAcc(1, 'Bajaj Finance', last4: '1111'),
          loanAcc(2, 'Bajaj Finance', last4: '2222'),
          const LoanAccount(
            id: 3,
            bankName: 'Axis Bank',
            principalMinor: 1000,
            tenureMonths: 2,
          ),
          loanAcc(4, 'Axis Bank'),
        ],
        payments: const [],
        today: today,
      );
      final dups = Loans.duplicates(a);
      expect(dups.length, 1);
      expect(dups.single.into.accountId, 3);
      expect(dups.single.from.accountId, 4);
    });
  });

  group('Links and forms (FR-15-06, FR-15-10, TC-15-06)', () {
    test('keyOf and old encodings round trip', () {
      expect(LoanLinks.keyOf('  Acme ', null), 'acme');
      expect(LoanLinks.keyOf(null, 'a@upi'), 'a@upi');
      expect(LoanLinks.keyOf(null, null), '');
      final links = LoanLinks.decode(
        tx: ['5:9', 'bad'],
        payee: ['9:acme: finance'],
        manual: ['acme'],
      );
      expect(links.tx, {5: 9});
      expect(links.payee, {'acme: finance': 9});
      expect(links.encodeTxSet(), {'5:9'});
      expect(links.encodePayeeSet(), {'9:acme: finance'});
      expect(links.manualPayees, {'acme'});
    });

    test('EMI alone with a tenure is enough (worked example 5)', () {
      final t = Loans.termsFromForm(emiMinor: 500000, tenureMonths: 24)!;
      expect(t.principalMinor, 12000000);
      expect(t.rateBps, 0);
      expect(Loans.termsFromForm(emiMinor: 500000), isNull);
      expect(Loans.termsFromForm(emiMinor: 500, tenureMonths: 601), isNull);
      expect(Loans.termsFromForm(emiMinor: 500, tenureMonths: 0), isNull);
      expect(
        Loans.termsFromForm(
          principalMinor: 100,
          rateBps: 6001,
          tenureMonths: 3,
        ),
        isNull,
      );
      final p = Loans.termsFromForm(
        principalMinor: 100,
        rateBps: 6000,
        tenureMonths: 3,
      )!;
      expect(p.rateBps, 6000);
      expect(Loans.validEmiDay(0), isFalse);
      expect(Loans.validEmiDay(31), isTrue);
      expect(Loans.validEmiDay(32), isFalse);
    });
  });

  group('EmiPairing (FR-08-15)', () {
    final loanIds = {7};

    test('loan-side EMI pairs with a same-amount bank debit within 3 days', () {
      final bank = tx(
        d(2026, 10, 7),
        1234500,
        accountId: 1,
        channel: Channel.autoDebit,
        category: Category.other,
      );
      final loanSide = tx(d(2026, 10, 5), 1234500, accountId: 7);
      final r = EmiPairing.pair(
        tx: loanSide,
        accountId: 7,
        txOnLoan: true,
        candidates: [bank],
        loanAccountIds: loanIds,
      )!;
      expect(r.markTransferId, loanSide.id);
      expect(r.note, 'EMI also debited from your bank account');
      // The bank debit arriving second marks the loan side, not itself.
      final r2 = EmiPairing.pair(
        tx: bank,
        accountId: 1,
        txOnLoan: false,
        candidates: [loanSide],
        loanAccountIds: loanIds,
      )!;
      expect(r2.markTransferId, loanSide.id);
    });

    test('no pair: different amount, 4 days apart, plain bank debit', () {
      final loanSide = tx(d(2026, 10, 5), 1234500, accountId: 7);
      EmiPair? run(LedgerTx other) => EmiPairing.pair(
            tx: loanSide,
            accountId: 7,
            txOnLoan: true,
            candidates: [other],
            loanAccountIds: loanIds,
          );
      expect(run(tx(d(2026, 10, 7), 1234501, accountId: 1)), isNull);
      expect(run(tx(d(2026, 10, 9), 1234500, accountId: 1)), isNull);
      expect(
        run(
          tx(
            d(2026, 10, 6),
            1234500,
            accountId: 1,
            category: Category.other,
          ),
        ),
        isNull,
      );
      expect(run(tx(d(2026, 10, 6), 1234500, accountId: 7)), isNull);
      final notEmi =
          tx(d(2026, 10, 5), 1234500, accountId: 7, category: Category.other);
      expect(
        EmiPairing.pair(
          tx: notEmi,
          accountId: 7,
          txOnLoan: true,
          candidates: [tx(d(2026, 10, 6), 1234500, accountId: 1)],
          loanAccountIds: loanIds,
        ),
        isNull,
      );
    });
  });
}

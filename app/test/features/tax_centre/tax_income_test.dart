import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/tax_centre/domain/tax_calculator.dart';
import 'package:hisaab/features/tax_centre/domain/tax_deductions.dart';
import 'package:hisaab/features/tax_centre/domain/tax_income.dart';
import 'package:hisaab/features/tax_centre/domain/tax_plan.dart';
import 'package:hisaab/features/tax_centre/domain/tax_rules.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

var _n = 0;
int r(int rupees) => rupees * 100;

LedgerTx row(
  DateTime day,
  int rupees,
  Category category, {
  String merchant = 'Acme Payroll',
  TransactionType type = TransactionType.credit,
  String? note,
}) {
  _n++;
  return LedgerTx(
    id: _n,
    amountMinor: rupees * 100,
    currency: 'INR',
    type: type,
    bankName: 'Test Bank',
    accountLast4: '1234',
    accountKind: AccountKind.account,
    accountId: 1,
    merchant: merchant,
    note: note,
    channel: Channel.other,
    timestamp: epochMsOf(day, hour: 12),
    hasExplicitTime: true,
    category: category,
    transactionHash: 'h$_n',
    confidence: 1,
    needsReview: false,
    createdAt: 0,
  );
}

List<LedgerTx> salaries(DateTime from, int count, int rupees) => [
      for (var i = 0; i < count; i++)
        row(addMonths(DateTime.utc(from.year, from.month), i), rupees,
            Category.salary),
    ];

void main() {
  final today = DateTime.utc(2026, 10, 11);

  group('TaxIncome.estimate (FR-19-02, FR-19-14)', () {
    test('part year is projected at the latest salary', () {
      final txs = [
        ...salaries(DateTime.utc(2026, 4, 1), 6, 100000),
        row(DateTime.utc(2026, 6, 30), 3000, Category.income,
            merchant: 'Interest credit'),
        row(DateTime.utc(2026, 7, 2), 500, Category.income,
            merchant: 'Dividend Acme'),
      ];
      final e = TaxIncome.estimate(
        txs,
        DateTime.utc(2026, 4, 1),
        DateTime.utc(2027, 3, 31),
        today,
      );
      expect(e.estimated, isTrue);
      expect(e.monthsOfData, 6);
      expect(e.salarySoFar, r(600000));
      expect(e.salary, r(1200000));
      expect(e.interest, r(6000));
      expect(e.dividends, r(1000));
    });

    test('memory example: today 17 Oct, interest 3,000 over 6 months -> 6,000',
        () {
      final txs = [
        row(DateTime.utc(2026, 4, 2), 1, Category.other,
            type: TransactionType.debit),
        ...salaries(DateTime.utc(2026, 4, 1), 6, 100000),
        row(DateTime.utc(2026, 6, 30), 3000, Category.income,
            merchant: 'Interest credit'),
      ];
      final e = TaxIncome.estimate(
        txs,
        DateTime.utc(2026, 4, 1),
        DateTime.utc(2027, 3, 31),
        DateTime.utc(2026, 10, 17),
      );
      expect(e.monthsOfData, 6);
      expect(e.salary, r(1200000));
      expect(e.interest, r(6000));
      expect(e.savingsInterest, r(6000));
    });

    test('month in progress counts once it is nearly over', () {
      final txs = salaries(DateTime.utc(2026, 4, 1), 7, 100000);
      final late = TaxIncome.estimate(
        txs,
        DateTime.utc(2026, 4, 1),
        DateTime.utc(2027, 3, 31),
        DateTime.utc(2026, 10, 29), // 31-day month: 29 is not < 29
      );
      expect(late.monthsOfData, 7);
      final early = TaxIncome.estimate(
        txs,
        DateTime.utc(2026, 4, 1),
        DateTime.utc(2027, 3, 31),
        DateTime.utc(2026, 10, 28),
      );
      expect(early.monthsOfData, 6);
    });

    test('full year needs no estimate; FD interest is not savings interest',
        () {
      final txs = [
        ...salaries(DateTime.utc(2025, 4, 1), 12, 50000),
        row(DateTime.utc(2025, 5, 1), 2000, Category.income,
            merchant: 'FD interest'),
      ];
      final e = TaxIncome.estimate(
        txs,
        DateTime.utc(2025, 4, 1),
        DateTime.utc(2026, 3, 31),
        today,
      );
      expect(e.estimated, isFalse);
      expect(e.monthsOfData, 12);
      expect(e.salary, r(600000));
      expect(e.interest, r(2000));
      expect(e.savingsInterest, 0);
    });

    test('refunds, reimbursements and transfers are left out', () {
      final txs = [
        ...salaries(DateTime.utc(2025, 4, 1), 12, 10000),
        row(DateTime.utc(2025, 6, 1), 9000, Category.income,
            merchant: 'Reimbursement travel'),
        row(DateTime.utc(2025, 6, 2), 9000, Category.refund,
            merchant: 'Shop refund'),
        row(DateTime.utc(2025, 6, 3), 9000, Category.transfer,
            merchant: 'Own account', type: TransactionType.transfer),
        row(DateTime.utc(2025, 6, 4), 4000, Category.income,
            merchant: 'Freelance design'),
        row(DateTime.utc(2025, 6, 5), 15000, Category.income,
            merchant: 'Rent from tenant'),
      ];
      final e = TaxIncome.estimate(
        txs,
        DateTime.utc(2025, 4, 1),
        DateTime.utc(2026, 3, 31),
        today,
      );
      expect(e.other, r(4000));
      expect(e.rent, r(15000));
      expect(e.salary, r(120000));
    });

    test('no data gives nothing', () {
      final e = TaxIncome.estimate(
        const [],
        DateTime.utc(2026, 4, 1),
        DateTime.utc(2027, 3, 31),
        today,
      );
      expect(e.total, 0);
      expect(e.monthsOfData, 0);
    });
  });

  group('deduction detection (FR-19-05, FR-19-06)', () {
    final from = epochMsOf(DateTime.utc(2026, 4, 1));
    final to = epochMsOf(DateTime.utc(2027, 3, 31), hour: 23);
    DateTime d(int m) => DateTime.utc(2026, m, 10);

    test('80C items, NPS, health premiums and context investments', () {
      final txs = [
        row(d(5), 5000, Category.investment,
            merchant: 'PPF deposit', type: TransactionType.investment),
        row(d(6), 3000, Category.investment,
            merchant: 'Axis ELSS tax saver', type: TransactionType.investment),
        row(d(7), 2000, Category.investment,
            merchant: 'Sukanya Samriddhi', type: TransactionType.investment),
        row(d(8), 1000, Category.investment,
            merchant: 'NSC post office', type: TransactionType.investment),
        row(d(9), 4000, Category.investment,
            merchant: 'NPS Tier 1', type: TransactionType.investment),
        row(d(9), 7000, Category.investment,
            merchant: 'Index fund', type: TransactionType.investment),
        row(d(5), 12000, Category.insurance,
            merchant: 'Max Life premium', type: TransactionType.debit),
        row(d(5), 8000, Category.insurance,
            merchant: 'Niva Bupa Health', type: TransactionType.debit),
        row(d(5), 9000, Category.insurance,
            merchant: 'Car insurance', type: TransactionType.debit),
      ];
      final res = TaxDeductionDetector.detect(txs, from, to);
      final labels = {for (final i in res.items80C) i.label: i.amountMinor};
      expect(labels['PPF deposits'], r(5000));
      expect(labels['ELSS tax-saver funds'], r(3000));
      expect(labels['Sukanya Samriddhi'], r(2000));
      expect(labels['NSC'], r(1000));
      expect(labels['Life insurance premiums'], r(12000));
      expect(res.c80Calc, r(23000));
      expect(res.d80Calc, r(8000));
      expect(res.npsDetected, r(4000));
      expect(res.otherInvested, r(7000));
    });

    test('rows outside the period or under review are ignored', () {
      final out = row(DateTime.utc(2026, 3, 1), 5000, Category.investment,
          merchant: 'PPF', type: TransactionType.investment);
      final res = TaxDeductionDetector.detect([out], from, to);
      expect(res.items80C, isEmpty);
      expect(res.d80Calc, 0);
    });

    test('insurance kind: first match wins', () {
      expect(TaxDeductionDetector.kindOf('Star Health'), InsuranceKind.health);
      expect(TaxDeductionDetector.kindOf('LIC premium'), InsuranceKind.life);
      expect(TaxDeductionDetector.kindOf('Bike cover'), InsuranceKind.motor);
      expect(TaxDeductionDetector.kindOf('Acme'), InsuranceKind.other);
      expect(TaxDeductionDetector.kindOf('health life'), InsuranceKind.health);
    });

    test('EPF employee share of passbook growth', () {
      final fromMs = epochMsOf(DateTime.utc(2026, 4, 1));
      final toMs = epochMsOf(DateTime.utc(2027, 3, 31));
      final prev = epochMsOf(DateTime.utc(2026, 6, 1));
      final at = epochMsOf(DateTime.utc(2026, 9, 1));
      final h = EpfHolding(
          valueMinor: r(115670),
          previousValueMinor: r(100000),
          asOf: at,
          previousAsOf: prev);
      // Whole growth 15,670 inside the period; employee 12 / 15.67.
      expect(TaxDeductionDetector.epfShare(h, fromMs, toMs), r(12000));
      expect(
        TaxDeductionDetector.epfShare(
          const EpfHolding(
              valueMinor: 5, previousValueMinor: 9, asOf: 2, previousAsOf: 1),
          fromMs,
          toMs,
        ),
        0,
      );
      expect(
          TaxDeductionDetector.epfShare(const EpfHolding(), fromMs, toMs), 0);
      // Half the growth period lies before FY start: half the growth counts.
      final half = EpfHolding(
        valueMinor: r(115670),
        previousValueMinor: r(100000),
        asOf: fromMs + 10 * 86400000,
        previousAsOf: fromMs - 10 * 86400000,
      );
      expect(TaxDeductionDetector.epfShare(half, fromMs, toMs), r(6000));
    });
  });

  group('TaxPlan (FR-19-04, FR-19-07, FR-19-08)', () {
    const est = TaxIncomeEstimate(
        salary: 150000000,
        interest: 600000,
        savingsInterest: 600000,
        monthsOfData: 12);

    test('derived values and recommendation', () {
      final p = TaxPlan.compute(
        period: TaxPeriod.thisFy,
        fyStartYear: 2026,
        est: est,
        deductions: const DetectedDeductions(
            items80C: [TaxItem('PPF deposits', 15000000)]),
      );
      expect(p.hasIncome, isTrue);
      expect(p.c80, 15000000);
      expect(p.left80C, 0);
      expect(p.fyLabel, 'FY 2026-27');
      expect(p.income, 150600000);
      expect(p.newIsBetter, p.newRegime.total <= p.oldRegime.total);
      expect(p.saving, (p.newRegime.total - p.oldRegime.total).abs());
    });

    test('what-if overrides, back to calculated, and period label', () {
      final base = TaxPlan.compute(
          period: TaxPeriod.last12, fyStartYear: 2026, est: est);
      expect(base.fyLabel, 'Last 12 months');
      final w = base.withWhatIf(const TaxWhatIf(salary: 127500000));
      expect(w.whatIf.any, isTrue);
      expect(w.salaryUsed, 127500000);
      expect(w.newRegime.total > 0, isTrue); // interest pushes it over 12L
      final back = w.withWhatIf(const TaxWhatIf());
      expect(back.newRegime.total, base.newRegime.total);
      expect(const TaxWhatIf().any, isFalse);
    });

    test(
        'input mapping: 80TTA uses the smaller of interest and savings interest',
        () {
      final i = TaxPlan.inputOf(
        est: const TaxIncomeEstimate(interest: 500000, savingsInterest: 200000),
        deductions: const DetectedDeductions(),
        whatIf: const TaxWhatIf(interest: 100000),
      );
      expect(i.savingsInterest, 100000);
      expect(i.otherIncome, 100000);
    });

    test('no income -> hasIncome false and nil tax', () {
      final p = TaxPlan.compute(
          period: TaxPeriod.thisFy,
          fyStartYear: 2026,
          est: const TaxIncomeEstimate());
      expect(p.hasIncome, isFalse);
      expect(p.newRegime.total, 0);
      expect(
          TaxCalculator.slabLines(
              p.newRegime.taxable, p.rules.newRegime.slabs[AgeBand.below60]!),
          isEmpty);
    });
  });
}

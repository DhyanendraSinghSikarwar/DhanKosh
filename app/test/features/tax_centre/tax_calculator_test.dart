import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/tax_centre/domain/tax_calculator.dart';
import 'package:hisaab/features/tax_centre/domain/tax_rules.dart';

int r(int rupees) => rupees * 100;

final rules = TaxRules.fy2026_27;

RegimeTax newR(int salary, {int other = 0, TaxInput Function(TaxInput)? f}) {
  final i = TaxInput(salary: r(salary), otherIncome: r(other));
  return TaxCalculator.compute(rules, Regime.newRegime, f == null ? i : f(i));
}

RegimeTax oldR(int salary, {TaxInput Function(TaxInput)? f}) {
  final i = TaxInput(salary: r(salary));
  return TaxCalculator.compute(rules, Regime.oldRegime, f == null ? i : f(i));
}

void main() {
  group('worked examples (memory 19 section 10, FR-19-03)', () {
    test('A new 12,75,000 -> nil', () {
      final t = newR(1275000);
      expect(t.taxable, r(1200000));
      expect(t.slabTax, r(60000));
      expect(t.rebate, r(60000));
      expect(t.total, 0);
    });
    test('B new 15,00,000', () {
      final t = newR(1500000);
      expect(t.taxable, r(1425000));
      expect(t.slabTax, r(93750));
      expect(t.rebate, 0);
      expect(t.cess, r(3750));
      expect(t.total, r(97500));
    });
    test('C old 15,00,000 with 80C 1,50,000', () {
      final t = oldR(1500000, f: (i) => i.copyWith(c80: r(150000)));
      expect(t.taxable, r(1300000));
      expect(t.slabTax, r(202500));
      expect(t.cess, r(8100));
      expect(t.total, r(210600));
    });
    test('D new 12,85,000 marginal relief', () {
      final t = newR(1285000);
      expect(t.taxable, r(1210000));
      expect(t.slabTax, r(61500));
      expect(t.rebate, r(51500));
      expect(t.slabTax - t.rebate, r(10000));
      expect(t.cess, r(400));
      expect(t.total, r(10400));
    });
    test('E new 60,75,000 surcharge 10%', () {
      final t = newR(6075000);
      expect(t.taxable, r(6000000));
      expect(t.slabTax, r(1380000));
      expect(t.surcharge, r(138000));
      expect(t.cess, r(60720));
      expect(t.total, r(1578720));
    });
    test('F new 50,85,000 surcharge marginal relief', () {
      final t = newR(5085000);
      expect(t.taxable, r(5010000));
      expect(t.slabTax, r(1083000));
      expect(t.surcharge, r(7000));
      expect(t.cess, r(43600));
      expect(t.total, r(1133600));
    });
    test('G new 20,00,000 with LTCG 2,25,000', () {
      final t = newR(2000000, f: (i) => i.copyWith(ltcgEquity: r(225000)));
      expect(t.taxable, r(1925000));
      expect(t.specialIncome, r(100000));
      expect(t.specialTax, r(12500));
    });
    test('H old 4,00,000 -> rebate wipes the tax', () {
      final t = oldR(400000);
      expect(t.taxable, r(350000));
      expect(t.slabTax, r(5000));
      expect(t.rebate, r(5000));
      expect(t.total, 0);
    });
  });

  group('port of Kotlin TaxCalculatorTest', () {
    test('seven lakh salary new regime is nil', () {
      expect(newR(700000).total, 0);
    });
    test('twenty five lakh', () {
      final t = newR(2500000);
      expect(t.slabTax, r(307500));
      expect(t.total, r(319800));
    });
    test('one crore twenty lakh surcharge 15%', () {
      final t = newR(12075000);
      expect(t.slabTax, r(3180000));
      expect(t.surcharge, r(477000));
      expect(t.total, r(3803280));
    });
    test('new regime surcharge capped at 25%', () {
      final t = newR(60075000);
      expect(t.surcharge, t.slabTax * 25 ~/ 100);
    });
    test('old regime surcharge reaches 37%', () {
      final t = oldR(60050000);
      expect(t.surcharge, t.slabTax * 37 ~/ 100);
    });
    test('old regime five lakh is nil', () {
      final t = oldR(500000);
      expect(t.taxable, r(450000));
      expect(t.slabTax, r(10000));
      expect(t.total, 0);
    });
    test('old regime ten lakh with and without deductions', () {
      expect(oldR(1000000).total, r(106600));
      final d = oldR(
        1000000,
        f: (i) => i.copyWith(c80: r(150000), d80Self: r(25000)),
      );
      expect(d.taxable, r(775000));
      expect(d.total, r(70200));
    });
    test('old regime deductions are capped', () {
      final d = oldR(
        1000000,
        f: (i) => i.copyWith(
          c80: r(400000),
          d80Self: r(90000),
          nps1B: r(80000),
          homeLoanInterest: r(500000),
        ),
      );
      expect(d.deductions, r(150000 + 25000 + 50000 + 200000));
    });
    test('old regime fifteen lakh', () {
      expect(oldR(1500000).total, r(257400));
    });
    test('new regime ignores old deductions but keeps employer NPS', () {
      final a = newR(1500000);
      final b = newR(
        1500000,
        f: (i) => i.copyWith(c80: r(150000), d80Self: r(25000)),
      );
      expect(a.total, b.total);
      final e = newR(1500000, f: (i) => i.copyWith(employerNps: r(100000)));
      expect(e.deductions, r(100000));
    });
    test('senior and super senior old regime', () {
      RegimeTax run(int sal, AgeBand a) => TaxCalculator.compute(
            rules,
            Regime.oldRegime,
            TaxInput(salary: r(sal), age: a),
          );
      expect(run(1000000, AgeBand.senior).total, r(104000));
      expect(run(1000000, AgeBand.superSenior).total, r(93600));
      expect(run(550000, AgeBand.senior).total, 0);
    });
    test('capital gains are separate and not rebated', () {
      final t = newR(1275000, f: (i) => i.copyWith(ltcgEquity: r(225000)));
      expect(t.specialIncome, r(100000));
      expect(t.specialTax, r(12500));
      expect(t.rebate, 0);
      expect(t.total, r(75400));
    });
    test('low income keeps rebate on slab tax but not on gains', () {
      final t = newR(500000, f: (i) => i.copyWith(stcgEquity: r(100000)));
      expect(t.rebate, r(1250));
      expect(t.specialTax, r(20000));
      expect(t.total, r(20800));
    });
    test('unused basic exemption absorbs gains', () {
      final t = TaxCalculator.compute(
        rules,
        Regime.newRegime,
        TaxInput(stcgEquity: r(300000)),
      );
      expect(t.total, 0);
    });
    test('LTCG under the exemption is free', () {
      final t = newR(2500000, f: (i) => i.copyWith(ltcgEquity: r(125000)));
      expect(t.specialTax, 0);
    });
    test('rules per year', () {
      expect(TaxRules.forYear(2027).fyStartYear, 2026);
      expect(TaxRules.forYear(2025).fyStartYear, 2025);
      expect(TaxRules.forYear(2020).fyStartYear, 2024);
      final t = TaxCalculator.compute(
        TaxRules.fy2024_25,
        Regime.newRegime,
        TaxInput(salary: r(775000)),
      );
      expect(t.total, 0);
      final above = TaxCalculator.compute(
        TaxRules.fy2024_25,
        Regime.newRegime,
        TaxInput(salary: r(975000)),
      );
      expect(above.total > 0, isTrue);
    });
    test('rent gets the 30% deduction', () {
      final t = TaxCalculator.compute(
        rules,
        Regime.newRegime,
        TaxInput(rent: r(1000000)),
      );
      expect(t.gross, r(700000));
    });
  });

  group('rounding, slab lines and FY labels (FR-19-12, FR-19-13)', () {
    test('roundRupee is half up to the rupee', () {
      expect(TaxCalculator.roundRupee(149), 100);
      expect(TaxCalculator.roundRupee(150), 200);
      expect(TaxCalculator.roundRupee(49), 0);
      expect(TaxCalculator.roundRupee(50), 100);
      expect(TaxCalculator.roundRupee(1250, 10), 100 * 1); // 125 paise -> Rs 1
      expect(TaxCalculator.roundRupee(0), 0);
    });
    test('slabLines reach only the slabs the income reaches', () {
      final slabs = rules.newRegime.slabs[AgeBand.below60]!;
      final lines = TaxCalculator.slabLines(r(1425000), slabs);
      expect(lines.length, 4);
      expect(lines[0].tax, 0);
      expect(lines[1].taxedPart, r(400000));
      expect(lines[1].tax, r(20000));
      expect(lines[2].tax, r(40000));
      expect(lines[3].to, r(1600000));
      expect(lines[3].taxedPart, r(225000));
      expect(
        lines.fold<int>(0, (a, l) => a + l.tax),
        TaxCalculator.slabTax(r(1425000), slabs),
      );
      expect(TaxCalculator.slabLines(0, slabs), isEmpty);
      final top = TaxCalculator.slabLines(r(3000000), slabs).last;
      expect(top.to, isNull);
      expect(top.rate, 30);
      expect(top.taxedPart, r(600000));
    });
    test('financial year labels, file stem and period bounds', () {
      expect(FinancialYear.startYearOf(DateTime.utc(2026, 3, 31)), 2025);
      expect(FinancialYear.startYearOf(DateTime.utc(2026, 4, 1)), 2026);
      expect(FinancialYear.label(2026), 'FY 2026-27');
      expect(FinancialYear.label(2099), 'FY 2099-00');
      expect(FinancialYear.fileStem(2026), 'DhanKosh-tax-estimate-2026-27');
      expect(FinancialYear.fileStem(2008), 'DhanKosh-tax-estimate-2008-09');
      final today = DateTime.utc(2026, 10, 17);
      final cur = FinancialYear.bounds(TaxPeriod.thisFy, today);
      expect(cur.from, DateTime.utc(2026, 4, 1));
      expect(cur.to, DateTime.utc(2027, 3, 31));
      final prev = FinancialYear.bounds(TaxPeriod.lastFy, today);
      expect(prev.fyStartYear, 2025);
      expect(prev.label, 'FY 2025-26');
      final l12 = FinancialYear.bounds(TaxPeriod.last12, today);
      expect(l12.from, DateTime.utc(2025, 10, 18));
      expect(l12.to, today);
      expect(l12.fyStartYear, 2026);
      expect(l12.label, 'Last 12 months');
    });
  });
}

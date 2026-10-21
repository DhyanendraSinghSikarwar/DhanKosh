import 'package:hisaab/features/tax_centre/domain/tax_rules.dart';

/// Everything the calculator needs for one year; paise (FR-19-03).
class TaxInput {
  const TaxInput({
    this.salary = 0,
    this.otherIncome = 0,
    this.rent = 0,
    this.familyPension = 0,
    this.stcgEquity = 0,
    this.ltcgEquity = 0,
    this.age = AgeBand.below60,
    this.employerNps = 0,
    this.c80 = 0,
    this.d80Self = 0,
    this.d80Parents = 0,
    this.parentsSenior = false,
    this.nps1B = 0,
    this.homeLoanInterest = 0,
    this.savingsInterest = 0,
    this.hraOther = 0,
  });

  final int salary;
  final int otherIncome;
  final int rent;
  final int familyPension;
  final int stcgEquity;
  final int ltcgEquity;
  final AgeBand age;
  final int employerNps;
  final int c80;
  final int d80Self;
  final int d80Parents;
  final bool parentsSenior;
  final int nps1B;
  final int homeLoanInterest;
  final int savingsInterest;
  final int hraOther;

  TaxInput copyWith({
    int? salary,
    int? otherIncome,
    int? rent,
    int? stcgEquity,
    int? ltcgEquity,
    AgeBand? age,
    int? employerNps,
    int? c80,
    int? d80Self,
    int? d80Parents,
    bool? parentsSenior,
    int? nps1B,
    int? homeLoanInterest,
    int? savingsInterest,
    int? hraOther,
  }) =>
      TaxInput(
        salary: salary ?? this.salary,
        otherIncome: otherIncome ?? this.otherIncome,
        rent: rent ?? this.rent,
        familyPension: familyPension,
        stcgEquity: stcgEquity ?? this.stcgEquity,
        ltcgEquity: ltcgEquity ?? this.ltcgEquity,
        age: age ?? this.age,
        employerNps: employerNps ?? this.employerNps,
        c80: c80 ?? this.c80,
        d80Self: d80Self ?? this.d80Self,
        d80Parents: d80Parents ?? this.d80Parents,
        parentsSenior: parentsSenior ?? this.parentsSenior,
        nps1B: nps1B ?? this.nps1B,
        homeLoanInterest: homeLoanInterest ?? this.homeLoanInterest,
        savingsInterest: savingsInterest ?? this.savingsInterest,
        hraOther: hraOther ?? this.hraOther,
      );
}

/// One regime's working (FR-19-12).
class RegimeTax {
  const RegimeTax({
    required this.gross,
    required this.standardDeduction,
    required this.deductions,
    required this.taxable,
    required this.slabTax,
    required this.rebate,
    required this.cess,
    this.surcharge = 0,
    this.specialIncome = 0,
    this.specialTax = 0,
  });

  final int gross;
  final int standardDeduction;
  final int deductions;
  final int taxable;
  final int slabTax;
  final int rebate;
  final int cess;
  final int surcharge;
  final int specialIncome;
  final int specialTax;

  int get taxBeforeCess => slabTax - rebate + specialTax;
  int get total => taxBeforeCess + surcharge + cess;
  int get totalIncome => taxable + specialIncome;
}

/// One reached slab for the breakdown (FR-19-12).
class SlabLine {
  const SlabLine({
    required this.from,
    required this.to,
    required this.rate,
    required this.taxedPart,
    required this.tax,
  });

  final int from;

  /// Null for the open top slab ("Above {from}").
  final int? to;
  final int rate;
  final int taxedPart;
  final int tax;
}

/// Port of Kotlin `TaxCalculator`. Rounding is exact integer arithmetic:
/// "to the nearest rupee, half up" ([roundRupee]) of a fraction of paise;
/// identical to Kotlin `Math.round(paise / 100.0) * 100` for non-negative
/// values (a true half is exactly representable in a double).
abstract final class TaxCalculator {
  /// `round(num / den paise)` to a whole rupee, half up, as paise. [num] >= 0.
  static int roundRupee(int num, [int den = 1]) =>
      ((2 * num + den * 100) ~/ (2 * den * 100)) * 100;

  static RegimeTax compute(TaxRules rules, Regime regime, TaxInput i) {
    final r = rules.rulesFor(regime);
    final slabs = r.slabs[i.age]!;
    final salary = _max0(i.salary);
    final std = _min(salary, r.standardDeduction);
    final pension = _max0(i.familyPension);
    final pensionDed = _min(pension ~/ 3, r.familyPensionCap);
    final rentNet = _max0(i.rent) * (100 - rules.rentStandardPct) ~/ 100;
    final gross = salary + _max0(i.otherIncome) + pension + rentNet;
    final afterStd = _max0(gross - std - pensionDed);

    var claimed = _max0(i.employerNps);
    if (r.deductionsAllowed) {
      final senior = i.age != AgeBand.below60;
      claimed +=
          _min(i.c80, rules.limit80C) + _min(i.nps1B, rules.limit80CCD1B);
      claimed += _min(
        i.d80Self,
        senior ? rules.limit80DSenior : rules.limit80DBelow60,
      );
      claimed += _min(
        i.d80Parents,
        i.parentsSenior ? rules.limit80DSenior : rules.limit80DBelow60,
      );
      claimed += _min(i.homeLoanInterest, rules.limitHomeLoan);
      claimed += senior
          ? _min(_max0(i.savingsInterest), rules.limit80TTB)
          : _min(_max0(i.savingsInterest), rules.limit80TTA);
      claimed += _max0(i.hraOther);
    }
    final deductions = _min(afterStd, _max0(claimed));
    final taxable = afterStd - deductions;

    final ltcgAfterExempt = _max0(i.ltcgEquity - rules.ltcgExempt);
    final first = slabs.first;
    final shortfall = first.ratePct == 0 ? _max0(first.upTo! - taxable) : 0;
    final stcgT = _max0(_max0(i.stcgEquity) - shortfall);
    final ltcgT = _max0(
      ltcgAfterExempt - _max0(shortfall - _max0(i.stcgEquity)),
    );

    final core = _assemble(rules, r, slabs, taxable, stcgT, ltcgT);
    var surcharge = core.surcharge;
    final total = taxable + stcgT + ltcgT;
    final tier = _tierFor(r, total);
    if (tier != null) {
      // Marginal relief: tax plus surcharge never rises by more than the
      // income above the tier threshold.
      final over = total - tier.threshold;
      final cutNormal = _min(taxable, over);
      var left = over - cutNormal;
      final cutLtcg = _min(ltcgT, left);
      left -= cutLtcg;
      final cutStcg = _min(stcgT, left);
      final at = _assemble(
        rules,
        r,
        slabs,
        taxable - cutNormal,
        stcgT - cutStcg,
        ltcgT - cutLtcg,
      );
      final ceiling = at.tax + at.surcharge + over;
      surcharge = _min(surcharge, _max0(ceiling - core.tax));
    }
    final cess = roundRupee((core.tax + surcharge) * rules.cessPct, 100);
    return RegimeTax(
      gross: gross,
      standardDeduction: std + pensionDed,
      deductions: deductions,
      taxable: taxable,
      slabTax: core.slabTax,
      rebate: core.rebate,
      cess: cess,
      surcharge: surcharge,
      specialIncome: stcgT + ltcgT,
      specialTax: core.specialTax,
    );
  }

  static SurchargeTier? _tierFor(RegimeRules r, int total) {
    SurchargeTier? t;
    for (final x in r.surchargeTiers) {
      if (total > x.threshold) t = x;
    }
    return t;
  }

  static _Core _assemble(
    TaxRules rules,
    RegimeRules r,
    List<TaxSlab> slabs,
    int taxable,
    int stcgT,
    int ltcgT,
  ) {
    final slab = slabTax(taxable, slabs);
    final special = roundRupee(
      stcgT * rules.stcgPermille + ltcgT * rules.ltcgPermille,
      1000,
    );
    final total = taxable + stcgT + ltcgT;
    final int rebate;
    if (total <= r.rebateIncomeLimit) {
      rebate = _min(slab, r.rebateMax);
    } else if (r.rebateMarginalRelief && stcgT + ltcgT == 0) {
      rebate = _max0(slab - (total - r.rebateIncomeLimit));
    } else {
      rebate = 0;
    }
    final normalNet = slab - rebate;
    final rate = _tierFor(r, total)?.pct ?? 0;
    final cap = rules.specialSurchargeCapPct;
    final surcharge = roundRupee(
      normalNet * rate + special * (rate < cap ? rate : cap),
      100,
    );
    return _Core(slab, rebate, special, surcharge);
  }

  /// Tax on [taxable] at [slabs] before rebate and cess, to the rupee.
  static int slabTax(int taxable, List<TaxSlab> slabs) {
    var lower = 0;
    var num = 0;
    for (final s in slabs) {
      if (taxable <= lower) break;
      final top = s.upTo == null ? taxable : _min(taxable, s.upTo!);
      num += (top - lower) * s.ratePct;
      if (s.upTo == null) break;
      lower = s.upTo!;
    }
    return roundRupee(num, 100);
  }

  /// Slab lines for the UI: each slab while taxable > lower (FR-19-12).
  static List<SlabLine> slabLines(int taxable, List<TaxSlab> slabs) {
    final out = <SlabLine>[];
    var lower = 0;
    for (final s in slabs) {
      if (taxable <= lower) break;
      final top = s.upTo == null ? taxable : _min(taxable, s.upTo!);
      final part = top - lower;
      out.add(
        SlabLine(
          from: lower,
          to: s.upTo,
          rate: s.ratePct,
          taxedPart: part,
          tax: roundRupee(part * s.ratePct, 100),
        ),
      );
      if (s.upTo == null) break;
      lower = s.upTo!;
    }
    return out;
  }

  static int _min(int a, int b) => a < b ? a : b;
  static int _max0(int a) => a < 0 ? 0 : a;
}

class _Core {
  const _Core(this.slabTax, this.rebate, this.specialTax, this.surcharge);

  final int slabTax;
  final int rebate;
  final int specialTax;
  final int surcharge;

  int get tax => slabTax - rebate + specialTax;
}

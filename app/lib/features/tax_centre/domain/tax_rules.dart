// Tax rules as versioned data (FR-19-03, FR-19-15). All amounts are paise.
//
// OPEN QUESTION (memory 19 Open Question 1): FY2026-27 is a copy of the
// FY2025-26 rules, as in the Kotlin app ("Rules as of 2026-10-11"). The
// old-regime rebate and the capital-gains rates (111A 20%, 112A 12.5% above
// Rs 1.25 lakh) are NOT confirmed against the official 2026-27 page. Treat
// FY2026-27 as provisional; no rules are invented here beyond the copy.

enum Regime { newRegime, oldRegime }

/// Age on the last day of the year.
enum AgeBand { below60, senior, superSenior }

enum TaxPeriod { thisFy, lastFy, last12 }

/// Slab up to [upTo] (inclusive) taxed at [ratePct]; null [upTo] is the open
/// top slab.
class TaxSlab {
  const TaxSlab(this.upTo, this.ratePct);

  final int? upTo;
  final int ratePct;
}

/// Surcharge tier: total income above [threshold] pays [pct] percent.
class SurchargeTier {
  const SurchargeTier(this.threshold, this.pct);

  final int threshold;
  final int pct;
}

class RegimeRules {
  const RegimeRules({
    required this.slabs,
    required this.standardDeduction,
    required this.familyPensionCap,
    required this.rebateIncomeLimit,
    required this.rebateMax,
    required this.rebateMarginalRelief,
    required this.surchargeTiers,
    required this.deductionsAllowed,
  });

  final Map<AgeBand, List<TaxSlab>> slabs;
  final int standardDeduction;
  final int familyPensionCap;
  final int rebateIncomeLimit;
  final int rebateMax;
  final bool rebateMarginalRelief;
  final List<SurchargeTier> surchargeTiers;

  /// New regime allows only employer NPS.
  final bool deductionsAllowed;
}

const _lakh = 10000000; // Rs 1 lakh in paise
const _crore = 100 * _lakh;

Map<AgeBand, List<TaxSlab>> _same(List<TaxSlab> s) => {
      for (final a in AgeBand.values) a: s,
    };

const _oldSlabs = <AgeBand, List<TaxSlab>>{
  AgeBand.below60: [
    TaxSlab(250000 * 100, 0),
    TaxSlab(5 * _lakh, 5),
    TaxSlab(10 * _lakh, 20),
    TaxSlab(null, 30),
  ],
  AgeBand.senior: [
    TaxSlab(3 * _lakh, 0),
    TaxSlab(5 * _lakh, 5),
    TaxSlab(10 * _lakh, 20),
    TaxSlab(null, 30),
  ],
  AgeBand.superSenior: [
    TaxSlab(5 * _lakh, 0),
    TaxSlab(10 * _lakh, 20),
    TaxSlab(null, 30),
  ],
};

const _oldSurcharge = [
  SurchargeTier(50 * _lakh, 10),
  SurchargeTier(_crore, 15),
  SurchargeTier(2 * _crore, 25),
  SurchargeTier(5 * _crore, 37),
];
const _newSurcharge = [
  SurchargeTier(50 * _lakh, 10),
  SurchargeTier(_crore, 15),
  SurchargeTier(2 * _crore, 25),
];

final _oldRegime = RegimeRules(
  slabs: _oldSlabs,
  standardDeduction: 50000 * 100,
  familyPensionCap: 15000 * 100,
  rebateIncomeLimit: 5 * _lakh,
  rebateMax: 12500 * 100,
  rebateMarginalRelief: false,
  surchargeTiers: _oldSurcharge,
  deductionsAllowed: true,
);

class TaxRules {
  const TaxRules({
    required this.fyStartYear,
    required this.newRegime,
    required this.oldRegime,
    this.cessPct = 4,
    this.stcgPermille = 200,
    this.ltcgPermille = 125,
    this.ltcgExempt = 125000 * 100,
    this.specialSurchargeCapPct = 15,
    this.limit80C = 150000 * 100,
    this.limit80CCD1B = 50000 * 100,
    this.limit80DBelow60 = 25000 * 100,
    this.limit80DSenior = 50000 * 100,
    this.limit80TTA = 10000 * 100,
    this.limit80TTB = 50000 * 100,
    this.limitHomeLoan = 200000 * 100,
    this.rentStandardPct = 30,
  });

  final int fyStartYear;
  final RegimeRules newRegime;
  final RegimeRules oldRegime;
  final int cessPct;

  /// STCG 111A 20% and LTCG 112A 12.5%, in per-mille so math stays integer.
  final int stcgPermille;
  final int ltcgPermille;
  final int ltcgExempt;
  final int specialSurchargeCapPct;
  final int limit80C;
  final int limit80CCD1B;
  final int limit80DBelow60;
  final int limit80DSenior;
  final int limit80TTA;
  final int limit80TTB;
  final int limitHomeLoan;
  final int rentStandardPct;

  TaxRules copyWith({int? fyStartYear}) => TaxRules(
        fyStartYear: fyStartYear ?? this.fyStartYear,
        newRegime: newRegime,
        oldRegime: oldRegime,
        cessPct: cessPct,
        stcgPermille: stcgPermille,
        ltcgPermille: ltcgPermille,
        ltcgExempt: ltcgExempt,
        specialSurchargeCapPct: specialSurchargeCapPct,
        limit80C: limit80C,
        limit80CCD1B: limit80CCD1B,
        limit80DBelow60: limit80DBelow60,
        limit80DSenior: limit80DSenior,
        limit80TTA: limit80TTA,
        limit80TTB: limit80TTB,
        limitHomeLoan: limitHomeLoan,
        rentStandardPct: rentStandardPct,
      );

  RegimeRules rulesFor(Regime r) =>
      r == Regime.newRegime ? newRegime : oldRegime;

  /// FY2024-25: new slabs from Budget July 2024, rebate Rs 25,000 to Rs 7L.
  static final fy2024_25 = TaxRules(
    fyStartYear: 2024,
    newRegime: RegimeRules(
      slabs: _same(const [
        TaxSlab(3 * _lakh, 0),
        TaxSlab(7 * _lakh, 5),
        TaxSlab(10 * _lakh, 10),
        TaxSlab(12 * _lakh, 15),
        TaxSlab(15 * _lakh, 20),
        TaxSlab(null, 30),
      ]),
      standardDeduction: 75000 * 100,
      familyPensionCap: 25000 * 100,
      rebateIncomeLimit: 7 * _lakh,
      rebateMax: 25000 * 100,
      rebateMarginalRelief: true,
      surchargeTiers: _newSurcharge,
      deductionsAllowed: false,
    ),
    oldRegime: _oldRegime,
  );

  /// FY2025-26: Budget 2025, nil tax up to Rs 12 lakh.
  static final fy2025_26 = TaxRules(
    fyStartYear: 2025,
    newRegime: RegimeRules(
      slabs: _same(const [
        TaxSlab(4 * _lakh, 0),
        TaxSlab(8 * _lakh, 5),
        TaxSlab(12 * _lakh, 10),
        TaxSlab(16 * _lakh, 15),
        TaxSlab(20 * _lakh, 20),
        TaxSlab(24 * _lakh, 25),
        TaxSlab(null, 30),
      ]),
      standardDeduction: 75000 * 100,
      familyPensionCap: 25000 * 100,
      rebateIncomeLimit: 12 * _lakh,
      rebateMax: 60000 * 100,
      rebateMarginalRelief: true,
      surchargeTiers: _newSurcharge,
      deductionsAllowed: false,
    ),
    oldRegime: _oldRegime,
  );

  /// FY2026-27: copy of FY2025-26 (see the open question at the top).
  static final fy2026_27 = fy2025_26.copyWith(fyStartYear: 2026);

  static final all = [fy2024_25, fy2025_26, fy2026_27];
  static final latest = fy2026_27;

  /// Last rule set with `fyStartYear <= year`, else FY2024-25.
  static TaxRules forYear(int fyStartYear) {
    TaxRules? best;
    for (final r in all) {
      if (r.fyStartYear <= fyStartYear) best = r;
    }
    return best ?? fy2024_25;
  }
}

/// Financial-year helpers (1 April to 31 March).
abstract final class FinancialYear {
  /// Start year of the FY containing [day] (April starts a new FY).
  static int startYearOf(DateTime day) =>
      day.month >= 4 ? day.year : day.year - 1;

  /// "FY 2026-27".
  static String label(int fyStartYear) =>
      'FY $fyStartYear-${_yy(fyStartYear + 1)}';

  /// Share file name stem `DhanKosh-tax-estimate-2026-27` (FR-19-10).
  static String fileStem(int fyStartYear) =>
      'DhanKosh-tax-estimate-$fyStartYear-${_yy(fyStartYear + 1)}';

  static String _yy(int y) => (y % 100).toString().padLeft(2, '0');

  static DateTime start(int fyStartYear) => DateTime.utc(fyStartYear, 4, 1);
  static DateTime end(int fyStartYear) => DateTime.utc(fyStartYear + 1, 3, 31);

  /// Period bounds (inclusive) for [period] at [today]: this FY, last FY, or
  /// last 12 months (`today - 12 months + 1 day .. today`, current FY rules).
  static ({DateTime from, DateTime to, int fyStartYear, String label}) bounds(
    TaxPeriod period,
    DateTime today,
  ) {
    final cur = startYearOf(today);
    switch (period) {
      case TaxPeriod.thisFy:
        return (
          from: start(cur),
          to: end(cur),
          fyStartYear: cur,
          label: label(cur),
        );
      case TaxPeriod.lastFy:
        return (
          from: start(cur - 1),
          to: end(cur - 1),
          fyStartYear: cur - 1,
          label: label(cur - 1),
        );
      case TaxPeriod.last12:
        final m = today.year * 12 + today.month - 1 - 12;
        final y = m ~/ 12;
        final mo = m % 12 + 1;
        final len = DateTime.utc(y, mo + 1, 0).day;
        final back = DateTime.utc(y, mo, today.day < len ? today.day : len);
        return (
          from: back.add(const Duration(days: 1)),
          to: today,
          fyStartYear: cur,
          label: 'Last 12 months',
        );
    }
  }
}

import 'package:hisaab/features/tax_centre/domain/tax_calculator.dart';
import 'package:hisaab/features/tax_centre/domain/tax_deductions.dart';
import 'package:hisaab/features/tax_centre/domain/tax_income.dart';
import 'package:hisaab/features/tax_centre/domain/tax_rules.dart';

/// What-if figures typed for one visit; null = use the calculated value.
/// Never persisted (FR-19-08). Paise.
class TaxWhatIf {
  const TaxWhatIf({
    this.salary,
    this.interest,
    this.dividends,
    this.rent,
    this.otherIncome,
    this.stcg,
    this.ltcg,
    this.c80,
    this.d80,
    this.nps,
    this.homeLoan,
    this.hraOther,
    this.employerNps,
  });

  final int? salary;
  final int? interest;
  final int? dividends;
  final int? rent;
  final int? otherIncome;
  final int? stcg;
  final int? ltcg;
  final int? c80;
  final int? d80;
  final int? nps;
  final int? homeLoan;
  final int? hraOther;
  final int? employerNps;

  bool get any => [
        salary,
        interest,
        dividends,
        rent,
        otherIncome,
        stcg,
        ltcg,
        c80,
        d80,
        nps,
        homeLoan,
        hraOther,
        employerNps,
      ].any((e) => e != null);
}

/// Both regimes for a period with the Kotlin `TaxState` derived values
/// (FR-19-03, FR-19-04, FR-19-07). Build with [TaxPlan.compute].
class TaxPlan {
  const TaxPlan._({
    required this.period,
    required this.fyStartYear,
    required this.est,
    required this.deductions,
    required this.whatIf,
    required this.newRegime,
    required this.oldRegime,
  });

  factory TaxPlan.compute({
    required TaxPeriod period,
    required int fyStartYear,
    required TaxIncomeEstimate est,
    DetectedDeductions deductions = const DetectedDeductions(),
    TaxWhatIf whatIf = const TaxWhatIf(),
  }) {
    final rules = TaxRules.forYear(fyStartYear);
    final input = inputOf(est: est, deductions: deductions, whatIf: whatIf);
    return TaxPlan._(
      period: period,
      fyStartYear: fyStartYear,
      est: est,
      deductions: deductions,
      whatIf: whatIf,
      newRegime: TaxCalculator.compute(rules, Regime.newRegime, input),
      oldRegime: TaxCalculator.compute(rules, Regime.oldRegime, input),
    );
  }

  final TaxPeriod period;
  final int fyStartYear;
  final TaxIncomeEstimate est;
  final DetectedDeductions deductions;
  final TaxWhatIf whatIf;
  final RegimeTax newRegime;
  final RegimeTax oldRegime;

  TaxRules get rules => TaxRules.forYear(fyStartYear);

  /// "FY 2026-27" or "Last 12 months".
  String get fyLabel => period == TaxPeriod.last12
      ? 'Last 12 months'
      : FinancialYear.label(fyStartYear);

  int get c80 => whatIf.c80 ?? deductions.c80Calc;
  int get d80 => whatIf.d80 ?? deductions.d80Calc;
  int get salaryUsed => whatIf.salary ?? est.salary;
  int get interestUsed => whatIf.interest ?? est.interest;
  int get dividendsUsed => whatIf.dividends ?? est.dividends;
  int get rentUsed => whatIf.rent ?? est.rent;
  int get otherUsed => whatIf.otherIncome ?? est.other;
  int get stcgUsed => whatIf.stcg ?? 0;
  int get ltcgUsed => whatIf.ltcg ?? 0;
  int get capitalGains => stcgUsed + ltcgUsed;
  int get nps => whatIf.nps ?? deductions.npsDetected;
  int get homeLoan => whatIf.homeLoan ?? 0;
  int get hraOther => whatIf.hraOther ?? 0;
  int get employerNps => whatIf.employerNps ?? 0;
  int get income =>
      salaryUsed + interestUsed + dividendsUsed + rentUsed + otherUsed;
  bool get hasIncome => income + capitalGains > 0;
  bool get newIsBetter => newRegime.total <= oldRegime.total;
  int get saving => (newRegime.total - oldRegime.total).abs();
  int get left80C => rules.limit80C - c80 < 0 ? 0 : rules.limit80C - c80;

  /// Calculator input mapping (memory 19 section 10). Age is below 60;
  /// parents and family pension are unused (Open Question 3).
  static TaxInput inputOf({
    required TaxIncomeEstimate est,
    required DetectedDeductions deductions,
    TaxWhatIf whatIf = const TaxWhatIf(),
  }) {
    final interest = whatIf.interest ?? est.interest;
    final savings =
        interest < est.savingsInterest ? interest : est.savingsInterest;
    return TaxInput(
      salary: whatIf.salary ?? est.salary,
      otherIncome: interest +
          (whatIf.dividends ?? est.dividends) +
          (whatIf.otherIncome ?? est.other),
      rent: whatIf.rent ?? est.rent,
      stcgEquity: whatIf.stcg ?? 0,
      ltcgEquity: whatIf.ltcg ?? 0,
      employerNps: whatIf.employerNps ?? 0,
      c80: whatIf.c80 ?? deductions.c80Calc,
      d80Self: whatIf.d80 ?? deductions.d80Calc,
      nps1B: whatIf.nps ?? deductions.npsDetected,
      homeLoanInterest: whatIf.homeLoan ?? 0,
      savingsInterest: savings,
      hraOther: whatIf.hraOther ?? 0,
    );
  }

  /// Same plan with other what-if figures (period switch passes an empty one).
  TaxPlan withWhatIf(TaxWhatIf o) => TaxPlan.compute(
        period: period,
        fyStartYear: fyStartYear,
        est: est,
        deductions: deductions,
        whatIf: o,
      );
}

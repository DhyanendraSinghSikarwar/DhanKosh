import 'package:hisaab/features/tax_centre/domain/tax_plan.dart';
import 'package:hisaab/features/tax_centre/domain/tax_rules.dart';
import 'package:hisaab/shared/report/report_document.dart';

/// Disclaimer on every tax export (FR-19-11).
const taxDisclaimer =
    'Estimate from tracked transactions, not tax advice. Check figures with '
    'your accountant before filing.';

/// Builds the tax-year summary export (FR-19-09..11).
abstract final class TaxReportBuilder {
  /// Income, detected deductions and the two-regime comparison of [plan].
  static ReportDocument build(TaxPlan plan) {
    String m(int v) => reportMoney(v, paise: false);
    final n = plan.newRegime;
    final o = plan.oldRegime;
    final rows80C = [
      for (final i in plan.deductions.items80C) [i.label, m(i.amountMinor)],
    ];
    final rows80D = [
      for (final i in plan.deductions.items80D) [i.label, m(i.amountMinor)],
    ];
    return ReportDocument(
      title: 'DhanKosh tax estimate',
      subtitle: plan.fyLabel,
      fileStem: plan.period == TaxPeriod.last12
          ? 'DhanKosh-tax-estimate-last-12-months'
          : FinancialYear.fileStem(plan.fyStartYear),
      footer: taxDisclaimer,
      sections: [
        ReportSection(
          heading: 'Income',
          rows: [
            ['Salary', m(plan.salaryUsed)],
            ['Interest', m(plan.interestUsed)],
            ['Dividends', m(plan.dividendsUsed)],
            ['Rent', m(plan.rentUsed)],
            ['Other', m(plan.otherUsed)],
            ['Capital gains', m(plan.capitalGains)],
            ['Total income', m(plan.income + plan.capitalGains)],
          ],
        ),
        ReportSection(
          heading: 'Deductions detected',
          rows: [
            ['Section 80C', m(plan.c80)],
            ...rows80C,
            ['Section 80D', m(plan.d80)],
            ...rows80D,
            ['NPS', m(plan.nps)],
          ],
          note: 'Old regime only; the new regime allows the standard '
              'deduction.',
        ),
        ReportSection(
          heading: 'Regime comparison',
          columns: const ['', 'New regime', 'Old regime'],
          rows: [
            ['Gross income', m(n.gross), m(o.gross)],
            [
              'Standard deduction',
              m(n.standardDeduction),
              m(o.standardDeduction),
            ],
            ['Deductions', m(n.deductions), m(o.deductions)],
            ['Taxable income', m(n.taxable), m(o.taxable)],
            ['Tax before cess', m(n.taxBeforeCess), m(o.taxBeforeCess)],
            ['Cess', m(n.cess), m(o.cess)],
            ['Total tax', m(n.total), m(o.total)],
          ],
          note: plan.hasIncome
              ? '${plan.newIsBetter ? 'New' : 'Old'} regime is cheaper by '
                  '${m(plan.saving)}.'
              : 'No income found for this period.',
        ),
      ],
    );
  }
}

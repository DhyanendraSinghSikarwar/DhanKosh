import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/backup_export/domain/report_builders.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/tax_centre/domain/tax_income.dart';
import 'package:hisaab/features/tax_centre/domain/tax_plan.dart';
import 'package:hisaab/features/tax_centre/domain/tax_report_builder.dart';
import 'package:hisaab/features/tax_centre/domain/tax_rules.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/report/pdf_report_renderer.dart';
import 'package:hisaab/shared/report/report_document.dart';
import 'package:parser_core/parser_core.dart' hide HoldingKind;

import '../../support/parsed.dart';

LedgerTx tx(
  int id,
  int amount,
  TransactionType type,
  String merchant,
  Category cat, {
  int ts = t0,
}) =>
    LedgerTx(
      id: id,
      amountMinor: amount,
      currency: 'INR',
      type: type,
      bankName: 'Test Bank',
      accountKind: AccountKind.account,
      channel: Channel.upi,
      timestamp: ts,
      hasExplicitTime: true,
      category: cat,
      transactionHash: 'h$id',
      confidence: 0.9,
      needsReview: false,
      createdAt: ts,
      merchant: merchant,
      inrMinor: amount,
    );

String pdfText(List<int> bytes) => latin1.decode(bytes);

/// The PDF writer puts each word in its own `(word)` string.
Matcher hasWords(String phrase) => allOf([
      for (final w in phrase.split(' ')) contains('($w)'),
    ]);

void main() {
  // FR-24-29
  test('reportMoney uses integer math and en-IN grouping', () {
    expect(reportMoney(12345650), 'Rs 1,23,456.50');
    expect(reportMoney(500), 'Rs 5.00');
    expect(reportMoney(-250000, paise: false), '-Rs 2,500');
    expect(reportMoney(99999999999), 'Rs 99,99,99,999.99');
  });

  group('period report (FR-24-29)', () {
    final txs = [
      tx(1, 5000000, TransactionType.credit, 'Acme Payroll', Category.salary),
      tx(2, 120000, TransactionType.debit, 'Big Bazaar', Category.groceries),
      tx(3, 80000, TransactionType.debit, 'Big Bazaar', Category.groceries),
      tx(4, 30000, TransactionType.debit, 'Cafe Blue', Category.food),
      tx(5, 999999, TransactionType.transfer, 'Own', Category.other),
      tx(
        6,
        1000,
        TransactionType.debit,
        'Old',
        Category.food,
        ts: t0 - 99 * 86400000,
      ),
    ];
    final doc = ReportBuilders.period(
      label: 'September 2026',
      fileStem: 'DhanKosh-summary-2026-09',
      txs: txs,
      fromMs: t0 - 5 * 86400000,
      toMs: t0 + 5 * 86400000,
      budgets: const [
        Budget(category: Category.groceries, monthlyLimitMinor: 300000),
      ],
      assetsMinor: 100000000,
      liabilitiesMinor: 25000000,
    );

    test('totals, categories, merchants, budgets, net worth', () {
      final summary = doc.sections.first.rows;
      expect(summary[0], ['Income', 'Rs 50,000.00']);
      expect(summary[1], ['Spent', 'Rs 2,300.00']);
      final cats = doc.sections[1].rows;
      expect(cats.first.first, 'Groceries');
      expect(cats.first[2], '86%');
      final merchants = doc.sections[2].rows;
      expect(merchants.first, ['Big Bazaar', '2', 'Rs 2,000.00']);
      final budget = doc.sections[3].rows.single;
      expect(budget, ['Groceries', 'Rs 3,000', 'Rs 2,000', 'Rs 1,000']);
      expect(doc.sections.last.rows.last, ['Net worth', 'Rs 7,50,000']);
    });

    test('PDF bytes start with %PDF and carry the expected text', () async {
      final bytes = await renderReportPdf(doc, compress: false);
      expect(pdfText(bytes.sublist(0, 5)), '%PDF-');
      final text = pdfText(bytes);
      expect(text, hasWords('Big Bazaar'));
      expect(text, hasWords('Rs 50,000.00'));
      expect(text, hasWords('September 2026'));
      expect(text, hasWords('not sent anywhere.'));
    });

    test('compressed output is still a PDF', () async {
      final bytes = await renderReportPdf(doc);
      expect(pdfText(bytes.sublist(0, 5)), '%PDF-');
    });
  });

  test('non-Latin text is replaced, not dropped silently', () async {
    final bytes = await renderReportPdf(
      const ReportDocument(
        title: 'T',
        subtitle: 'S',
        footer: 'F',
        fileStem: 'x',
        sections: [
          ReportSection(
            heading: 'H',
            rows: [
              ['Caf\u00e9', '\u20b9 5'],
            ],
          ),
        ],
      ),
      compress: false,
    );
    expect(pdfText(bytes), hasWords('? 5'));
  });

  test('portfolio report (FR-24-30)', () async {
    final doc = ReportBuilders.portfolio(
      asOf: '26 October 2026',
      holdings: const [
        Holding(
          id: 1,
          kind: HoldingKind.mutualFund,
          name: 'Test Index Fund',
          identifier: 'MF:test',
          source: HoldingSource.manual,
          updatedAt: 1,
          valueMinor: 1500000,
          investedMinor: 1000000,
        ),
      ],
    );
    expect(doc.sections.first.rows[2], ['Gain', 'Rs 5,000.00']);
    expect(doc.sections.first.rows[3], ['Return', '50.0%']);
    final text = pdfText(await renderReportPdf(doc, compress: false));
    expect(text, hasWords('Test Index Fund'));
  });

  test('tax report has income, deductions, regimes, disclaimer', () async {
    final plan = TaxPlan.compute(
      period: TaxPeriod.lastFy,
      fyStartYear: 2025,
      est: const TaxIncomeEstimate(salary: 120000000),
    );
    final doc = TaxReportBuilder.build(plan);
    expect(doc.fileStem, 'DhanKosh-tax-estimate-2025-26');
    expect(doc.sections.map((s) => s.heading), [
      'Income',
      'Deductions detected',
      'Regime comparison',
    ]);
    expect(doc.sections.first.rows.first, ['Salary', 'Rs 12,00,000']);
    final text = pdfText(await renderReportPdf(doc, compress: false));
    expect(text, hasWords('not tax advice.'));
    expect(text, hasWords('New regime'));
    expect(text, hasWords('FY 2025-26'));
  });
}

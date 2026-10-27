import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/spend_calc.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_summary.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/report/report_document.dart';
import 'package:parser_core/parser_core.dart';

/// Footer on every report (FR-24-31).
const reportFooter =
    'Made on your phone by DhanKosh. This file was not sent anywhere.';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Builds [ReportDocument]s from ledger and portfolio data (pure; FR-24-29,
/// FR-24-30).
String _pct(int part, int total) =>
    total <= 0 ? '0%' : '${part * 100 ~/ total}%';

String _ret(double? v) => v == null ? 'n/a' : '${v.toStringAsFixed(1)}%';

String _dash(int? minor) => minor == null ? '-' : reportMoney(minor);

abstract final class ReportBuilders {
  static int _inr(LedgerTx t) =>
      t.inrMinor ?? (t.currency == 'INR' ? t.amountMinor : 0);

  static bool _counts(LedgerTx t) => !t.needsReview && t.duplicateOfId == null;

  /// Month name and year, e.g. `October 2026`.
  static String monthLabel(int year, int month) =>
      '${_months[month - 1]} $year';

  /// Income, spend by category, top merchants, budgets and net worth for
  /// [txs] inside [fromMs, toMs). [months] scales the monthly budget limits
  /// (1 for a month, 12 for a year).
  static ReportDocument period({
    required String label,
    required String fileStem,
    required Iterable<LedgerTx> txs,
    required int fromMs,
    required int toMs,
    required List<Budget> budgets,
    int months = 1,
    int? assetsMinor,
    int? liabilitiesMinor,
  }) {
    final inRange = txs
        .where((t) => t.timestamp >= fromMs && t.timestamp < toMs)
        .where(_counts)
        .toList();
    final rows =
        inRange.where((t) => t.type != TransactionType.transfer).toList();
    // ADR-0011: headline on the cash basis; categories show card purchases.
    final cash = SpendCalc.totals(inRange, context: txs);
    final spent = cash.spentMinor;
    final earned = cash.incomeMinor;
    final spend = rows.where((t) => t.type == TransactionType.debit).toList();
    final categorised = spend.fold(0, (a, t) => a + _inr(t));

    final byCat = <Category, int>{};
    for (final t in spend) {
      byCat.update(t.category, (v) => v + _inr(t), ifAbsent: () => _inr(t));
    }
    final cats = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final byMerchant = <String, (int, int)>{};
    for (final t in spend) {
      final cur = byMerchant[t.title] ?? (0, 0);
      byMerchant[t.title] = (cur.$1 + _inr(t), cur.$2 + 1);
    }
    final merchants = byMerchant.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));

    final budgetRows = [
      for (final b in budgets)
        if (b.monthlyLimitMinor > 0)
          [
            b.category.label,
            reportMoney(b.monthlyLimitMinor * months, paise: false),
            reportMoney(byCat[b.category] ?? 0, paise: false),
            reportMoney(
              b.monthlyLimitMinor * months - (byCat[b.category] ?? 0),
              paise: false,
            ),
          ],
    ];

    return ReportDocument(
      title: 'DhanKosh summary',
      subtitle: label,
      fileStem: fileStem,
      footer: reportFooter,
      sections: [
        ReportSection(
          heading: 'Summary',
          rows: [
            ['Income', reportMoney(earned)],
            ['Spent (cash basis)', reportMoney(spent)],
            ['Card purchases', reportMoney(cash.cardPurchasesMinor)],
            ['Saved', reportMoney(earned - spent)],
            ['Transactions', '${rows.length}'],
          ],
        ),
        ReportSection(
          heading: 'Spend by category',
          columns: const ['Category', 'Amount', 'Share'],
          rows: [
            for (final e in cats)
              [
                e.key.label,
                reportMoney(e.value),
                _pct(e.value, categorised),
              ],
          ],
        ),
        ReportSection(
          heading: 'Top merchants',
          columns: const ['Merchant', 'Payments', 'Amount'],
          rows: [
            for (final e in merchants.take(10))
              [e.key, '${e.value.$2}', reportMoney(e.value.$1)],
          ],
        ),
        ReportSection(
          heading: 'Budgets',
          columns: const ['Category', 'Limit', 'Spent', 'Left'],
          rows: budgetRows,
        ),
        if (assetsMinor != null && liabilitiesMinor != null)
          ReportSection(
            heading: 'Net worth today',
            rows: [
              ['Assets', reportMoney(assetsMinor, paise: false)],
              ['Liabilities', reportMoney(liabilitiesMinor, paise: false)],
              [
                'Net worth',
                reportMoney(assetsMinor - liabilitiesMinor, paise: false),
              ],
            ],
          ),
      ],
    );
  }

  /// Holdings with value, cost and gain (FR-24-30).
  static ReportDocument portfolio({
    required List<Holding> holdings,
    required String asOf,
    int? assetsMinor,
    int? liabilitiesMinor,
  }) {
    final sum = summarisePortfolio(holdings);
    final sorted = [...holdings]
      ..sort((a, b) => (b.valueMinor ?? 0).compareTo(a.valueMinor ?? 0));
    final classes = sum.byClass.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ReportDocument(
      title: 'DhanKosh portfolio',
      subtitle: 'As of $asOf',
      fileStem: 'DhanKosh-portfolio',
      footer: reportFooter,
      sections: [
        ReportSection(
          heading: 'Summary',
          rows: [
            ['Value', reportMoney(sum.valueMinor)],
            ['Invested', reportMoney(sum.investedMinor)],
            ['Gain', reportMoney(sum.gainMinor)],
            [
              'Return',
              _ret(sum.returnPct),
            ],
            if (assetsMinor != null && liabilitiesMinor != null)
              [
                'Net worth',
                reportMoney(assetsMinor - liabilitiesMinor, paise: false),
              ],
          ],
          note: 'Return covers holdings with a known cost only.',
        ),
        ReportSection(
          heading: 'Allocation',
          columns: const ['Class', 'Value', 'Share'],
          rows: [
            for (final e in classes)
              [
                e.key.label,
                reportMoney(e.value),
                _pct(e.value, sum.valueMinor),
              ],
          ],
        ),
        ReportSection(
          heading: 'Holdings',
          columns: const ['Name', 'Value', 'Invested', 'Gain'],
          rows: [
            for (final h in sorted)
              if ((h.valueMinor ?? 0) > 0)
                [
                  h.name,
                  reportMoney(h.valueMinor!),
                  _dash(h.investedMinor),
                  _dash(h.gainMinor),
                ],
          ],
        ),
      ],
    );
  }
}

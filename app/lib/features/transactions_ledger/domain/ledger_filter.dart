import 'package:parser_core/parser_core.dart';

enum TxKind { all, income, spends, investments, transfers, review }

/// List filter (FR-08-05..07). Review rows show only for [TxKind.review].
class LedgerFilter {
  const LedgerFilter({
    this.kind = TxKind.all,
    this.fromMs,
    this.toMs,
    this.query = '',
    this.accountId,
    this.category,
    this.sources = const {},
    this.banks = const {},
    this.minMinor,
    this.maxMinor,
  });

  final TxKind kind;

  /// Inclusive start / exclusive end, epoch ms.
  final int? fromMs;
  final int? toMs;

  /// Matches merchant, bank, note, reference, UPI id, category label or a
  /// whole-rupee amount prefix.
  final String query;

  /// Includes accounts merged into this one.
  final int? accountId;
  final Category? category;
  final Set<Source> sources;
  final Set<String> banks;

  /// Inclusive amount bounds in paise (FR-20-21); null is open.
  final int? minMinor;
  final int? maxMinor;
}

/// Totals for a period; review rows and rows without an INR value excluded.
class PeriodTotals {
  const PeriodTotals({
    this.spentMinor = 0,
    this.investedMinor = 0,
    this.incomeMinor = 0,
    this.refundMinor = 0,
    this.count = 0,
  });

  /// DEBIT, not transfer.
  final int spentMinor;

  /// INVESTMENT.
  final int investedMinor;

  /// CREDIT, not transfer and not refund.
  final int incomeMinor;

  /// CREDIT in the refund category.
  final int refundMinor;
  final int count;

  /// Spend less refunds.
  int get netSpentMinor => spentMinor - refundMinor;

  /// Out as the KPI strip shows it (includes investments).
  int get outMinor => spentMinor + investedMinor;
}

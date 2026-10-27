import 'package:hisaab/features/analytics/domain/chart_data.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Everything the Category detail screen shows (FR-09-14). Paise.
class CategoryDetail {
  /// Creates a detail.
  const CategoryDetail({
    required this.id,
    required this.category,
    required this.customCategoryId,
    required this.txs,
    required this.thisMonth,
    required this.subcategories,
    required this.monthly,
    required this.merchants,
    required this.budgetLimitMinor,
  });

  /// Filters [all] spend rows to the category and builds the series.
  /// [months] are first-of-month days, the last being the current month.
  factory CategoryDetail.build({
    required String id,
    required Category category,
    required int? customCategoryId,
    required List<LedgerTx> all,
    required List<DateTime> months,
    int? budgetLimitMinor,
  }) {
    final txs = [
      for (final t in all)
        if (customCategoryId != null
            ? t.customCategoryId == customCategoryId
            : t.category == category && t.customCategoryId == null)
          t,
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final cur = months.last;
    bool inCur(LedgerTx t) {
      final d = DateTime.fromMillisecondsSinceEpoch(
        t.timestamp,
        isUtc: true,
      ).add(const Duration(hours: 5, minutes: 30));
      return d.year == cur.year && d.month == cur.month;
    }

    final now = txs.where(inCur).toList();
    return CategoryDetail(
      id: id,
      category: category,
      customCategoryId: customCategoryId,
      txs: txs,
      thisMonth: now.fold(0, (a, t) => a + LedgerMath.rupees(t)),
      subcategories: ChartData.subcategories(now, category),
      monthly: ChartData.categoryMonthly(txs, category, months),
      merchants: LedgerMath.topMerchants(now),
      budgetLimitMinor: budgetLimitMinor,
    );
  }

  final String id;
  final Category category;
  final int? customCategoryId;

  /// Newest first, 12 months.
  final List<LedgerTx> txs;

  /// Spend in the current month.
  final int thisMonth;

  /// Current month by sub-category.
  final List<(String, int)> subcategories;

  /// 12 months, oldest first.
  final List<(DateTime, int)> monthly;

  /// Top merchants of the current month.
  final List<MerchantSpend> merchants;

  /// Monthly budget limit, null when none.
  final int? budgetLimitMinor;
}

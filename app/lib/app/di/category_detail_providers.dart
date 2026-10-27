import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/categorization/domain/category_detail.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:parser_core/parser_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_detail_providers.g.dart';

/// Category detail for route id [id]: a built-in `Category.name` or
/// `custom:<n>` (FR-09-14). Includes card purchases (ADR-0011).
@riverpod
Stream<CategoryDetail> categoryDetail(Ref ref, String id) async* {
  final category = Category.values.where((c) => c.name == id).firstOrNull;
  final customId = id.startsWith('custom:')
      ? int.tryParse(id.substring('custom:'.length))
      : null;
  if (category == null && customId == null) return;
  final budgets = ref.watch(budgetsProvider).value ?? const [];
  final today = dayOf(DateTime.now().millisecondsSinceEpoch);
  final cur = DateTime.utc(today.year, today.month);
  final months = [for (var i = 11; i >= 0; i--) addMonths(cur, -i)];
  final limit = category == null
      ? null
      : budgets
          .where((b) => b.category == category)
          .map((b) => b.monthlyLimitMinor)
          .firstOrNull;
  await for (final all in ref
      .watch(transactionRepositoryProvider)
      .watch(LedgerFilter(fromMs: epochMsOf(months.first)))) {
    yield CategoryDetail.build(
      id: id,
      category: category ?? Category.other,
      customCategoryId: customId,
      all: all.where(LedgerMath.isSpend).toList(),
      months: months,
      budgetLimitMinor: limit,
    );
  }
}

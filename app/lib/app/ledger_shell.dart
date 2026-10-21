import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/categorization/presentation/category_sheet.dart';
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/search_filters/presentation/ledger_filter_bar.dart';
import 'package:hisaab/features/search_filters/presentation/ledger_view_notifier.dart';
import 'package:hisaab/features/transactions_ledger/presentation/transaction_detail_screen.dart';
import 'package:hisaab/features/transactions_ledger/presentation/transactions_ledger_screen.dart';

/// Composes the Transactions tab with the search/filter header, since
/// features may not import each other's presentation.
class TransactionsTab extends ConsumerWidget {
  /// Creates the tab.
  const TransactionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(ledgerViewProvider);
    return TransactionsLedgerScreen(
      filter: view.toFilter(DateTime.now()),
      periodLabel: switch (view.period) {
        PeriodKind.thisMonth => 'This month',
        PeriodKind.lastMonth => 'Last month',
        PeriodKind.custom => 'Custom range',
        PeriodKind.all => 'All time',
      },
      filterBuilder: (context, count) => LedgerFilterBar(resultCount: count),
    );
  }
}

/// Transaction detail wired to the category sheet.
class TransactionDetailRoute extends StatelessWidget {
  /// Creates the route page for [id].
  const TransactionDetailRoute({required this.id, super.key});

  /// Row id.
  final int id;

  @override
  Widget build(BuildContext context) => TransactionDetailScreen(
        id: id,
        pickCategory: (ctx, t) => showCategorySheet(
          ctx,
          current: t.category,
          currentCustomId: t.customCategoryId,
          ruleKey: MerchantRule.keyOf(t.merchant, t.upiId),
        ),
      );
}

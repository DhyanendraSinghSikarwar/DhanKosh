import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/groups_people_providers.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/categorization/presentation/category_sheet.dart';
import 'package:hisaab/features/people_split/presentation/split_sheet.dart';
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/search_filters/presentation/ledger_filter_bar.dart';
import 'package:hisaab/features/search_filters/presentation/ledger_view_notifier.dart';
import 'package:hisaab/features/transaction_groups/presentation/group_picker_sheet.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
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
      periodLabel: view.period == PeriodKind.custom
          ? 'Custom range'
          : periodLabel(view.period),
      filterBuilder: (context, count) => LedgerFilterBar(resultCount: count),
      titleActions: const LedgerTitleActions(),
      sourceFilter: const LedgerSourceDropdown(),
      pickCategory: (ctx, t) => showCategorySheet(
        ctx,
        current: t.category,
        currentCustomId: t.customCategoryId,
      ),
    );
  }
}

/// Transaction detail wired to the category sheet.
/// Rows for groups and splitting (F-39, F-40), added to the detail screen.
List<DetailAction> _extraRows(
  BuildContext context,
  WidgetRef ref,
  LedgerTx tx,
) {
  final groups = ref.watch(txGroupNamesProvider(tx.id)).value ?? const [];
  final shares = ref.watch(txSharesProvider(tx.id)).value ?? const {};
  return [
    DetailAction(
      label: 'Groups',
      value: groups.isEmpty ? 'Add' : groups.join(', '),
      tag: 'detail_groups',
      onTap: () => showGroupPicker(context, ref, tx.id),
    ),
    DetailAction(
      label: 'Split with people',
      value: shares.isEmpty ? 'Add' : '${shares.length} people',
      tag: 'detail_split_people',
      onTap: () => showSplitSheet(context, ref, tx),
    ),
  ];
}

class TransactionDetailRoute extends StatelessWidget {
  /// Creates the route page for [id].
  const TransactionDetailRoute({required this.id, super.key});

  /// Row id.
  final int id;

  @override
  Widget build(BuildContext context) => TransactionDetailScreen(
        id: id,
        extraActions: _extraRows,
        pickCategory: (ctx, t) => showCategorySheet(
          ctx,
          current: t.category,
          currentCustomId: t.customCategoryId,
          ruleKey: MerchantRule.keyOf(t.merchant, t.upiId),
        ),
      );
}

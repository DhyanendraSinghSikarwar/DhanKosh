import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/search_filters/presentation/ledger_view_notifier.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:parser_core/parser_core.dart';

final StreamProvider<List<Account>> _visibleAccountsProvider =
    StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchVisible(),
);

const Map<TxKind, String> _kinds = {
  TxKind.all: 'All',
  TxKind.income: 'Income',
  TxKind.spends: 'Spends',
  TxKind.investments: 'Investments',
  TxKind.transfers: 'Transfers',
};

const Map<PeriodKind, String> _periods = {
  PeriodKind.thisMonth: 'This month',
  PeriodKind.lastMonth: 'Last month',
  PeriodKind.custom: 'Custom',
  PeriodKind.all: 'All time',
};

/// Search box, period chips, type chips and account/category filters
/// (FR-20-03, FR-20-11..16, FR-08-05, FR-08-06).
class LedgerFilterBar extends ConsumerStatefulWidget {
  /// Creates the bar; [resultCount] feeds the match badge.
  const LedgerFilterBar({this.resultCount, super.key});

  /// Rows currently shown.
  final int? resultCount;

  @override
  ConsumerState<LedgerFilterBar> createState() => _LedgerFilterBarState();
}

class _LedgerFilterBarState extends ConsumerState<LedgerFilterBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // FR-20-11: 120 ms debounce.
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      ref.read(ledgerViewProvider.notifier).setQuery(v.trim());
    });
    setState(() {});
  }

  void _clearText() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(ledgerViewProvider.notifier).setQuery('');
    setState(() {});
  }

  Future<void> _pickRange() async {
    final notifier = ref.read(ledgerViewProvider.notifier);
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      helpText: 'Choose dates',
    );
    if (r != null) notifier.setCustom(r.start, r.end);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(ledgerViewProvider);
    final notifier = ref.read(ledgerViewProvider.notifier);
    final accounts = ref.watch(_visibleAccountsProvider).value ?? const [];
    final scheme = Theme.of(context).colorScheme;
    final count = widget.resultCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('ledger_search'),
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search merchant, amount, note…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (count != null)
                        Container(
                          key: const Key('ledger_match_count'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count'),
                        ),
                      IconButton(
                        key: const Key('ledger_search_clear'),
                        icon: const Icon(Icons.close),
                        onPressed: _clearText,
                      ),
                    ],
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        _ChipRow(
          children: [
            for (final e in _periods.entries)
              ChoiceChip(
                key: Key('period_${e.key.name}'),
                label: Text(
                  e.key == PeriodKind.custom ? _customLabel(view) : e.value,
                ),
                selected: view.period == e.key,
                onSelected: (_) {
                  if (e.key == PeriodKind.custom) {
                    unawaited(_pickRange());
                  } else {
                    notifier.setPeriod(e.key);
                  }
                },
              ),
          ],
        ),
        _ChipRow(
          children: [
            for (final e in _kinds.entries)
              ChoiceChip(
                key: Key('kind_${e.key.name}'),
                label: Text(e.value),
                selected: view.kind == e.key,
                onSelected: (_) => notifier.setKind(e.key),
              ),
          ],
        ),
        _ChipRow(
          children: [
            PopupMenuButton<int>(
              key: const Key('account_filter'),
              onSelected: (v) => notifier.setAccount(v < 0 ? null : v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: -1, child: Text('All accounts')),
                for (final a in accounts)
                  PopupMenuItem(value: a.id, child: Text(a.label)),
              ],
              child: Chip(
                label: Text(_accountLabel(view.accountId, accounts)),
                backgroundColor:
                    view.accountId != null ? scheme.secondaryContainer : null,
                onDeleted: view.accountId == null
                    ? null
                    : () => notifier.setAccount(null),
              ),
            ),
            PopupMenuButton<String>(
              key: const Key('category_filter'),
              onSelected: (v) => notifier.setCategory(
                v.isEmpty ? null : Category.values.byName(v),
              ),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('All categories')),
                for (final c in Category.values)
                  PopupMenuItem(value: c.name, child: Text(c.label)),
              ],
              child: Chip(
                label: Text(view.category?.label ?? 'Category'),
                backgroundColor:
                    view.category != null ? scheme.secondaryContainer : null,
                onDeleted: view.category == null
                    ? null
                    : () => notifier.setCategory(null),
              ),
            ),
            if (view.hasChipFilters)
              TextButton(
                key: const Key('filters_clear'),
                onPressed: notifier.clear,
                child: const Text('Clear'),
              ),
          ],
        ),
      ],
    );
  }

  static String _customLabel(LedgerViewState v) {
    final s = v.customStart;
    if (v.period != PeriodKind.custom || s == null) return 'Custom';
    final e = v.customEnd ?? s;
    return '${s.day}/${s.month} – ${e.day}/${e.month}';
  }

  static String _accountLabel(int? id, List<Account> accounts) {
    if (id == null) return 'Account';
    for (final a in accounts) {
      if (a.id == id) return a.label;
    }
    return 'Account';
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in children)
              Padding(padding: const EdgeInsets.only(right: 8), child: c),
          ],
        ),
      );
}

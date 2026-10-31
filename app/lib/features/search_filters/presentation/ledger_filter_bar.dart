import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/scope_bar.dart' show PeriodChips;
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/search_filters/presentation/ledger_view_notifier.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/shared/widgets/app_dropdown.dart';
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

enum _SourceKind {
  all('All sources', null),
  accounts('Accounts', AccountKind.account),
  cards('Cards', AccountKind.card);

  const _SourceKind(this.label, this.kind);
  final String label;
  final AccountKind? kind;
}

const Map<Source, String> _sourceLabels = {
  Source.sms: 'SMS',
  Source.email: 'Email',
  Source.app: 'Notification',
  Source.statement: 'Statement',
  Source.manual: 'Manual',
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
  final _min = TextEditingController();
  final _max = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _min.dispose();
    _max.dispose();
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
        const PeriodChips(),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppDropdown<_SourceKind>(
              key: const Key('source_dropdown'),
              icon: Icons.account_balance_outlined,
              value: _SourceKind.values
                  .firstWhere((s) => s.kind == view.accountKind),
              options: _SourceKind.values,
              labelOf: (s) => s.label,
              onChanged: (s) => notifier.setAccountKind(s.kind),
            ),
          ),
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
                onPressed: () {
                  _min.clear();
                  _max.clear();
                  notifier.clear();
                },
                child: const Text('Clear'),
              ),
          ],
        ),
        _ChipRow(
          children: [
            for (final e in _sourceLabels.entries)
              FilterChip(
                key: Key('source_${e.key.name}'),
                label: Text(e.value),
                selected: view.sources.contains(e.key),
                onSelected: (_) => notifier.toggleSource(e.key),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _AmountField(
                fieldKey: const Key('amount_min'),
                controller: _min,
                label: 'Min ₹',
                onChanged: (v) => notifier.setAmountRange(
                  rupeesToMinor(v),
                  ref.read(ledgerViewProvider).maxMinor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AmountField(
                fieldKey: const Key('amount_max'),
                controller: _max,
                label: 'Max ₹',
                onChanged: (v) => notifier.setAmountRange(
                  ref.read(ledgerViewProvider).minMinor,
                  rupeesToMinor(v),
                ),
              ),
            ),
          ],
        ),
      ],
    );
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

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        key: fieldKey,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}

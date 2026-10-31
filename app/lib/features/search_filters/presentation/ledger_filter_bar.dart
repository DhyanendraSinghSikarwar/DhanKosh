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
import 'package:hisaab/shared/widgets/section_label.dart';
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
  all('All', null),
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

/// Whether the inline search field is open (title-row search icon).
class LedgerSearchOpen extends Notifier<bool> {
  @override
  bool build() => false;

  /// Opens or closes the field.
  set open(bool value) => state = value;
}

/// Provider of [LedgerSearchOpen].
final NotifierProvider<LedgerSearchOpen, bool> ledgerSearchOpenProvider =
    NotifierProvider<LedgerSearchOpen, bool>(LedgerSearchOpen.new);

/// Title-row icons: search toggle and the filter button with an
/// active-filter count badge (FR-20-03, FR-20-16).
class LedgerTitleActions extends ConsumerWidget {
  /// Creates the icons.
  const LedgerTitleActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(ledgerViewProvider);
    final open = ref.watch(ledgerSearchOpenProvider);
    final n = view.advancedFilterCount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('ledger_search_toggle'),
          tooltip: 'Search',
          icon: Icon(open ? Icons.search_off : Icons.search),
          onPressed: () {
            ref.read(ledgerSearchOpenProvider.notifier).open = !open;
            if (open) ref.read(ledgerViewProvider.notifier).setQuery('');
          },
        ),
        IconButton(
          key: const Key('ledger_filter_button'),
          tooltip: 'Filters',
          icon: Badge(
            key: const Key('ledger_filter_badge'),
            isLabelVisible: n > 0,
            label: Text('$n'),
            child: const Icon(Icons.filter_list),
          ),
          onPressed: () => showLedgerFilterSheet(context),
        ),
      ],
    );
  }
}

/// Source dropdown (All, Accounts, Cards) (FR-08-23).
class LedgerSourceDropdown extends ConsumerWidget {
  /// Creates the dropdown.
  const LedgerSourceDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(ledgerViewProvider);
    return AppDropdown<_SourceKind>(
      key: const Key('source_dropdown'),
      expanded: true,
      value: _SourceKind.values.firstWhere((s) => s.kind == view.accountKind),
      options: _SourceKind.values,
      labelOf: (s) => s.label,
      onChanged: (s) =>
          ref.read(ledgerViewProvider.notifier).setAccountKind(s.kind),
    );
  }
}

/// Period chips, plus the search field when opened from the title row
/// (FR-20-03, FR-20-11, FR-08-05).
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

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(ledgerSearchOpenProvider);
    final scheme = Theme.of(context).colorScheme;
    final count = widget.resultCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              key: const Key('ledger_search'),
              controller: _controller,
              autofocus: true,
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                isDense: true,
              ),
            ),
          ),
        const PeriodChips(),
      ],
    );
  }
}

/// Opens the advanced-filter sheet: type, account, category, source and
/// amount range (FR-20-12..16, FR-20-21).
Future<void> showLedgerFilterSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const LedgerFilterSheet(),
    );

/// Bottom sheet with the advanced ledger filters.
class LedgerFilterSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const LedgerFilterSheet({super.key});

  @override
  ConsumerState<LedgerFilterSheet> createState() => _LedgerFilterSheetState();
}

String _rupees(int? minor) {
  if (minor == null) return '';
  final r = minor ~/ 100;
  final p = minor % 100;
  return p == 0 ? '$r' : '$r.${p.toString().padLeft(2, '0')}';
}

class _LedgerFilterSheetState extends ConsumerState<LedgerFilterSheet> {
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    final v = ref.read(ledgerViewProvider);
    _min = TextEditingController(text: _rupees(v.minMinor));
    _max = TextEditingController(text: _rupees(v.maxMinor));
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(ledgerViewProvider);
    final notifier = ref.read(ledgerViewProvider.notifier);
    final accounts = ref.watch(_visibleAccountsProvider).value ?? const [];
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filters',
                    style: Theme.of(context).textTheme.titleMedium,
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
            const SectionLabel('Type', padding: EdgeInsets.only(bottom: 6)),
            Wrap(
              spacing: 8,
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
            const SizedBox(height: 12),
            const SectionLabel(
              'Account and category',
              padding: EdgeInsets.only(bottom: 6),
            ),
            Wrap(
              spacing: 8,
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
                    backgroundColor: view.accountId != null
                        ? scheme.secondaryContainer
                        : null,
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
                    const PopupMenuItem(
                      value: '',
                      child: Text('All categories'),
                    ),
                    for (final c in Category.values)
                      PopupMenuItem(value: c.name, child: Text(c.label)),
                  ],
                  child: Chip(
                    label: Text(view.category?.label ?? 'Category'),
                    backgroundColor: view.category != null
                        ? scheme.secondaryContainer
                        : null,
                    onDeleted: view.category == null
                        ? null
                        : () => notifier.setCategory(null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SectionLabel('Source', padding: EdgeInsets.only(bottom: 6)),
            Wrap(
              spacing: 8,
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
            const SizedBox(height: 12),
            const SectionLabel('Amount', padding: EdgeInsets.only(bottom: 6)),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('filters_done'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
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

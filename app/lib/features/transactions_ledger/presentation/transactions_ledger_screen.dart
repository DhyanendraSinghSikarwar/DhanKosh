import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/transactions_ledger/domain/day_groups.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_views.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_calendar_view.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_merchant_view.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_summary_strip.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_tx_tile.dart';
import 'package:hisaab/features/transactions_ledger/presentation/transaction_detail_screen.dart'
    show CategoryPicker;
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Transactions tab: filter header, summary strip and day cards
/// (FR-08-01, FR-08-02, FR-08-05..07, FR-20-18, FR-20-19), Calendar and
/// By-merchant segments (FR-08-03, FR-08-04, FR-08-21) and multi-select with
/// bulk category, merge and delete (FR-08-08).
class TransactionsLedgerScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [filter]; [filterBuilder] draws the search and
  /// chip header (supplied by the app shell, see search_filters).
  const TransactionsLedgerScreen({
    required this.filter,
    required this.periodLabel,
    this.filterBuilder,
    this.pickCategory,
    super.key,
  });

  /// What to list.
  final LedgerFilter filter;

  /// Caption for the period, e.g. "This month".
  final String periodLabel;

  /// Header above the summary; gets the shown-row count.
  final Widget Function(BuildContext context, int? count)? filterBuilder;

  /// Category picker for the bulk action; hidden when null.
  final CategoryPicker? pickCategory;

  @override
  ConsumerState<TransactionsLedgerScreen> createState() => _State();
}

bool _same(LedgerFilter a, LedgerFilter b) =>
    a.kind == b.kind &&
    a.fromMs == b.fromMs &&
    a.toMs == b.toMs &&
    a.query == b.query &&
    a.accountId == b.accountId &&
    a.category == b.category;

class _State extends ConsumerState<TransactionsLedgerScreen> {
  late Stream<List<LedgerTx>> _rows;
  LedgerSegment _segment = LedgerSegment.list;
  final Set<int> _selected = {};
  List<LedgerTx> _shown = const [];

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(int id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  Widget _tile(LedgerTx t, bool masked) => LedgerTxTile(
        tx: t,
        masked: masked,
        selecting: _selecting,
        selected: _selected.contains(t.id),
        onToggle: () => _toggle(t.id),
      );

  Future<void> _bulkDelete() async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $n transaction${n == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('bulk_delete_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(transactionRepositoryProvider)
        .deleteTransactions(_selected.toList());
    if (mounted) setState(_selected.clear);
  }

  Future<void> _bulkCategory() async {
    final pick = widget.pickCategory;
    if (pick == null) return;
    final first = _shown.firstWhere((t) => _selected.contains(t.id));
    final choice = await pick(context, first);
    if (choice == null || !mounted) return;
    await ref.read(transactionRepositoryProvider).setCategory(
          _selected.toList(),
          choice.category,
          customCategoryId: choice.customCategoryId,
        );
    if (mounted) setState(_selected.clear);
  }

  Future<void> _bulkMerge() async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Merge $n transactions into one?'),
        content: const Text('The oldest row is kept; the rest are removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('bulk_merge_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(transactionRepositoryProvider).mergeRows(_selected.toList());
    if (mounted) setState(_selected.clear);
  }

  AppBar _selectionBar() => AppBar(
        leading: IconButton(
          key: const Key('sel_close'),
          tooltip: 'Clear selection',
          icon: const Icon(Icons.close),
          onPressed: () => setState(_selected.clear),
        ),
        title: Text('${_selected.length} selected'),
        actions: [
          IconButton(
            key: const Key('sel_all'),
            tooltip: 'Select all',
            icon: const Icon(Icons.select_all),
            onPressed: () => setState(
              () => _selected.addAll(_shown.map((t) => t.id)),
            ),
          ),
          if (_selected.length > 1)
            IconButton(
              key: const Key('sel_merge'),
              tooltip: 'Merge',
              icon: const Icon(Icons.merge_type),
              onPressed: _bulkMerge,
            ),
          if (widget.pickCategory != null)
            IconButton(
              key: const Key('sel_category'),
              tooltip: 'Change category',
              icon: const Icon(Icons.label_outline),
              onPressed: _bulkCategory,
            ),
          IconButton(
            key: const Key('sel_delete'),
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _bulkDelete,
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    _rows = _open();
  }

  Stream<List<LedgerTx>> _open() =>
      ref.read(transactionRepositoryProvider).watch(widget.filter);

  @override
  void didUpdateWidget(TransactionsLedgerScreen old) {
    super.didUpdateWidget(old);
    if (!_same(old.filter, widget.filter)) _rows = _open();
  }

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final reviewCount = ref.watch(_reviewCountProvider).value ?? 0;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionBar()
            : AppBar(title: const Text('Transactions')),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton(
                key: const Key('ledger_add'),
                tooltip: 'Add transaction',
                onPressed: () => context.push('/transactions/add'),
                child: const Icon(Icons.add),
              ),
        body: StreamBuilder<List<LedgerTx>>(
          stream: _rows,
          builder: (context, snap) {
            final rows = snap.data;
            if (rows != null) _shown = rows;
            final header = widget.filterBuilder?.call(context, rows?.length);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                if (header != null) header,
                if (reviewCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AppCard(
                      key: const Key('review_banner'),
                      onTap: () => context.push('/review'),
                      child: Row(
                        children: [
                          const Icon(Icons.copy_all_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('$reviewCount need review'),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (rows == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  LedgerSummaryStrip(
                    summary: summarize(rows),
                    count: rows.length,
                    periodLabel: widget.periodLabel,
                    masked: masked,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<LedgerSegment>(
                    key: const Key('ledger_segments'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: LedgerSegment.list,
                        label: Text('List'),
                      ),
                      ButtonSegment(
                        value: LedgerSegment.calendar,
                        label: Text('Calendar'),
                      ),
                      ButtonSegment(
                        value: LedgerSegment.merchant,
                        label: Text('Merchant'),
                      ),
                    ],
                    selected: {_segment},
                    onSelectionChanged: (s) =>
                        setState(() => _segment = s.first),
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    SizedBox(height: 280, child: _empty())
                  else
                    switch (_segment) {
                      LedgerSegment.list => Column(
                          children: [
                            for (final g in groupByDay(rows))
                              _DayCard(
                                g,
                                masked: masked,
                                tile: (t) => _tile(t, masked),
                              ),
                          ],
                        ),
                      LedgerSegment.calendar => LedgerCalendarView(
                          rows: rows,
                          kind: widget.filter.kind,
                          masked: masked,
                          rangeStart: widget.filter.fromMs == null
                              ? null
                              : DateTime.fromMillisecondsSinceEpoch(
                                  widget.filter.fromMs!,
                                ),
                          rangeEnd: widget.filter.toMs == null
                              ? null
                              : DateTime.fromMillisecondsSinceEpoch(
                                  widget.filter.toMs!,
                                ),
                          rowBuilder: (t) => _tile(t, masked),
                        ),
                      LedgerSegment.merchant => LedgerMerchantView(
                          rows: rows,
                          masked: masked,
                          rowBuilder: (t) => _tile(t, masked),
                        ),
                    },
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // FR-20-19: empty state by cause.
  Widget _empty() {
    final f = widget.filter;
    final p = widget.periodLabel.toLowerCase();
    final String title;
    if (f.query.isNotEmpty) {
      title = 'Nothing matches “${f.query}” in $p.';
    } else if (f.kind != TxKind.all ||
        f.accountId != null ||
        f.category != null) {
      title = 'No transactions match these filters in $p.';
    } else {
      title = 'No transactions in $p.';
    }
    return EmptyState(
      key: const Key('ledger_empty'),
      icon: Icons.receipt_long_outlined,
      title: title,
    );
  }
}

final _reviewCountProvider = StreamProvider<int>(
  (ref) => ref.watch(transactionRepositoryProvider).watchReviewCount(),
);

class _DayCard extends StatelessWidget {
  const _DayCard(this.group, {required this.masked, required this.tile});
  final DayGroup group;
  final bool masked;
  final Widget Function(LedgerTx) tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = dayLabel(group.day, DateTime.now());
    final s = group.summary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: theme.textTheme.titleSmall),
                ),
                Text(
                  'Out ${formatAmount(s.spentMinor, masked: masked, paise: false)}',
                  key: Key('day_out_$label'),
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            for (final t in group.rows) tile(t),
          ],
        ),
      ),
    );
  }
}

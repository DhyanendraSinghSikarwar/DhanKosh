import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/transactions_ledger/domain/day_groups.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_summary_strip.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_tx_tile.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Transactions tab: filter header, summary strip and day cards
/// (FR-08-01, FR-08-02, FR-08-05..07, FR-20-18, FR-20-19). Calendar and
/// By-merchant views are deferred.
class TransactionsLedgerScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [filter]; [filterBuilder] draws the search and
  /// chip header (supplied by the app shell, see search_filters).
  const TransactionsLedgerScreen({
    required this.filter,
    required this.periodLabel,
    this.filterBuilder,
    super.key,
  });

  /// What to list.
  final LedgerFilter filter;

  /// Caption for the period, e.g. "This month".
  final String periodLabel;

  /// Header above the summary; gets the shown-row count.
  final Widget Function(BuildContext context, int? count)? filterBuilder;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: FloatingActionButton(
        key: const Key('ledger_add'),
        tooltip: 'Add transaction',
        onPressed: () => context.push('/transactions/add'),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<LedgerTx>>(
        stream: _rows,
        builder: (context, snap) {
          final rows = snap.data;
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
                if (rows.isEmpty)
                  SizedBox(height: 280, child: _empty())
                else
                  for (final g in groupByDay(rows)) _DayCard(g, masked: masked),
              ],
            ],
          );
        },
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
  const _DayCard(this.group, {required this.masked});
  final DayGroup group;
  final bool masked;

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
            for (final t in group.rows) LedgerTxTile(tx: t, masked: masked),
          ],
        ),
      ),
    );
  }
}

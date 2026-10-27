import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/dedup_review/presentation/compare_screen.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';
import 'package:intl/intl.dart';

final StreamProvider<List<ReviewPair>> _pairsProvider =
    StreamProvider.autoDispose<List<ReviewPair>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchReviewPairs(),
);

/// Possible duplicates: flagged row beside the row it may repeat, with
/// Merge and Keep separate (FR-07-12; basic compare).
class DedupReviewScreen extends ConsumerWidget {
  /// Creates the screen.
  const DedupReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairs = ref.watch(_pairsProvider);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final repo = ref.read(transactionRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Possible duplicates')),
      body: pairs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                key: Key('review_empty'),
                icon: Icons.check_circle_outline,
                title: 'Nothing to review',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PairCard(
                        p,
                        masked: masked,
                        onMerge: () => repo.mergeFlagged(p.flagged.id),
                        onKeep: () => repo.keepSeparate(p.flagged.id),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard(
    this.pair, {
    required this.masked,
    required this.onMerge,
    required this.onKeep,
  });
  final ReviewPair pair;
  final bool masked;
  final VoidCallback onMerge;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final id = pair.flagged.id;
    return AppCard(
      key: Key('pair_$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Side('New', pair.flagged, masked: masked)),
              const SizedBox(width: 12),
              Expanded(child: _Side('Existing', pair.target, masked: masked)),
            ],
          ),
          if (pair.flagged.reviewReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(pair.flagged.reviewReason!),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: Key('compare_$id'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => CompareScreen(pair)),
                ),
                child: const Text('Compare'),
              ),
              TextButton(
                key: Key('keep_$id'),
                onPressed: onKeep,
                child: const Text('Keep separate'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: Key('merge_$id'),
                onPressed: pair.target == null ? null : onMerge,
                child: const Text('Merge'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side(this.label, this.tx, {required this.masked});
  final String label;
  final LedgerTx? tx;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        if (t == null)
          const Text('Removed')
        else ...[
          Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            formatMoney(
              Money(t.amountMinor, currency: t.currency),
              masked: masked,
            ),
            style: theme.textTheme.titleMedium,
          ),
          Text(
            DateFormat('d MMM, h:mm a').format(
              DateTime.fromMillisecondsSinceEpoch(t.timestamp),
            ),
            style: theme.textTheme.bodySmall,
          ),
          Text(t.bankName, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

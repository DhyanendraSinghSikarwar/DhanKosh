import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/dedup_review/presentation/compare_screen.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/ui/app_dates.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

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
      appBar: AppBar(title: Text(t('Possible duplicates'))),
      body: pairs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: t('Could not load'),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                key: const Key('review_empty'),
                icon: Icons.check_circle_outline,
                title: t('Nothing to review'),
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
                child: Text(t('Compare')),
              ),
              TextButton(
                key: Key('keep_$id'),
                onPressed: onKeep,
                child: Text(t('Keep separate')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: Key('merge_$id'),
                onPressed: pair.target == null ? null : onMerge,
                child: Text(t('Merge')),
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
    final tt = tx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        if (tt == null)
          Text(t('Removed'))
        else ...[
          Text(tt.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            formatMoney(
              Money(tt.amountMinor, currency: tt.currency),
              masked: masked,
            ),
            style: theme.textTheme.titleMedium,
          ),
          Text(
            AppDates.format(
              DateTime.fromMillisecondsSinceEpoch(tt.timestamp),
              year: false,
              time: true,
            ),
            style: theme.textTheme.bodySmall,
          ),
          Text(tt.bankName, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

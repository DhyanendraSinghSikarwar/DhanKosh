import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/dedup_review/domain/compare_rows.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:intl/intl.dart';

/// Side-by-side New vs Existing with differences highlighted, and Merge /
/// Keep separate / Split (FR-07-11, FR-07-13).
class CompareScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [pair].
  const CompareScreen(this.pair, {super.key});

  final ReviewPair pair;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  List<TxSourceRow> _sources = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadSources());
  }

  Future<void> _loadSources() async {
    final t = widget.pair.target;
    if (t == null) return;
    final s = await ref.read(transactionRepositoryProvider).sourcesOf(t.id);
    if (mounted) setState(() => _sources = s);
  }

  Future<void> _split(TxSourceRow s) async {
    final t = widget.pair.target!;
    final id =
        await ref.read(transactionRepositoryProvider).splitSource(t.id, s.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(id == null ? 'Could not split' : 'Split into its own row'),
      ),
    );
    await _loadSources();
  }

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final repo = ref.read(transactionRepositoryProvider);
    final fresh = widget.pair.flagged;
    final existing = widget.pair.target;
    final theme = Theme.of(context);
    final diffs = existing == null
        ? const <FieldDiff>[]
        : compareRows(
            fresh,
            existing,
            money: (m, c) => formatMoney(Money(m, currency: c), masked: masked),
            when: (ms) => DateFormat('d MMM yyyy, h:mm a')
                .format(DateTime.fromMillisecondsSinceEpoch(ms)),
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Compare')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (existing == null)
            const Text('The existing row is gone.')
          else ...[
            Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  child: Text('New', style: theme.textTheme.labelLarge),
                ),
                Expanded(
                  child: Text('Existing', style: theme.textTheme.labelLarge),
                ),
              ],
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final d in diffs)
                    Container(
                      key: Key('diff_${d.label}'),
                      color: d.differs
                          ? theme.colorScheme.tertiaryContainer
                          : null,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              d.label,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Expanded(child: Text(d.newValue)),
                          Expanded(child: Text(d.existingValue)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (fresh.reviewReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(fresh.reviewReason!),
            ),
          if (_sources.length > 1) ...[
            const SizedBox(height: 16),
            Text(
              'Messages in the existing row',
              style: theme.textTheme.titleSmall,
            ),
            for (final s in _sources)
              ListTile(
                key: Key('split_src_${s.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text('${s.source.name.toUpperCase()} · ${s.sender}'),
                trailing: TextButton(
                  key: Key('split_${s.id}'),
                  onPressed: s.rawText == null ? null : () => _split(s),
                  child: const Text('Split'),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('compare_keep'),
                onPressed: () async {
                  await repo.keepSeparate(fresh.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Keep separate'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('compare_merge'),
                onPressed: existing == null
                    ? null
                    : () async {
                        await repo.mergeFlagged(fresh.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Merge'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/goals_providers.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// Compact card for Home: the first goal's progress and this month's
/// round-up. Empty until a goal exists (FR-36-09).
class GoalsSummaryCard extends ConsumerWidget {
  /// Creates the card.
  const GoalsSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalProgressListProvider).value ?? const [];
    if (goals.isEmpty) return const SizedBox.shrink();
    final g = goals.first;
    final r = ref.watch(roundUpThisMonthProvider).value;
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    String money(int m) => formatAmount(m, masked: masked, paise: false);
    return AppCard(
      key: const Key('goals-summary'),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/goals'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardHeader(
              'Goals',
              trailing: Text(
                g.goal.name,
                style: MockText.small(context),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: g.fraction,
                minHeight: 7,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${money(g.savedMinor)} of ${money(g.goal.targetMinor)}',
              style: MockText.body(context),
            ),
            if (r != null && r.totalMinor > 0)
              Text(
                'You could have saved ${money(r.totalMinor)} this month',
                style: MockText.small(context),
              ),
          ],
        ),
      ),
    );
  }
}

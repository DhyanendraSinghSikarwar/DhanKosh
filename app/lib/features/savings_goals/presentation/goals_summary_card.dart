import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/goals_providers.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

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
      child: InkWell(
        onTap: () => context.push('/goals'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.goal.name, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: g.fraction),
            const SizedBox(height: 6),
            Text('${money(g.savedMinor)} of ${money(g.goal.targetMinor)}'),
            if (r != null && r.totalMinor > 0)
              Text('You could have saved ${money(r.totalMinor)} this month'),
          ],
        ),
      ),
    );
  }
}

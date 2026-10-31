import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/goals_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/savings_goals/domain/goal_math.dart';
import 'package:hisaab/features/savings_goals/domain/goal_settings.dart';
import 'package:hisaab/features/savings_goals/domain/round_up.dart';
import 'package:hisaab/features/savings_goals/domain/salary_plan.dart';
import 'package:hisaab/features/savings_goals/presentation/contribution_sheet.dart';
import 'package:hisaab/features/savings_goals/presentation/goal_sheet.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

const _mon = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _day(int epochDay) {
  final d = DateTime.utc(1970).add(Duration(days: epochDay));
  return '${d.day} ${_mon[d.month - 1]} ${d.year}';
}

/// Savings goals, round-ups and the salary split plan (F-36). Route
/// `/goals`. Tracking only: no money moves.
class GoalsScreen extends ConsumerWidget {
  /// Creates the screen.
  const GoalsScreen({super.key});

  void _sheet(BuildContext context, Widget w) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => w,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalProgressListProvider).value ?? const [];
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    String money(int m) => formatAmount(m, masked: masked, paise: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Goals & salary plan')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        key: const Key('goal-add'),
        onPressed: () => _sheet(context, const GoalSheet()),
        icon: const Icon(Icons.add),
        label: const Text('Add goal'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (goals.isEmpty)
            const AppCard(
              child: Text('No goals yet. Add one.', key: Key('goals-empty')),
            ),
          for (final p in goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalCard(
                p: p,
                money: money,
                onEdit: () => _sheet(context, GoalSheet(goal: p.goal)),
                onAdd: () => _sheet(context, ContributionSheet(goal: p.goal)),
              ),
            ),
          const _RoundUpCard(),
          const SizedBox(height: 12),
          const _SalaryCard(),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.p,
    required this.money,
    required this.onEdit,
    required this.onAdd,
  });

  final GoalProgress p;
  final String Function(int) money;
  final VoidCallback onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = p.goal;
    return AppCard(
      key: Key('goal-${g.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(g.name, style: theme.textTheme.titleMedium)),
              IconButton(
                key: Key('goal-edit-${g.id}'),
                tooltip: 'Edit goal',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            ],
          ),
          LinearProgressIndicator(value: p.fraction),
          const SizedBox(height: 6),
          Text(
            '${money(p.savedMinor)} of ${money(g.targetMinor)}',
            key: Key('goal-saved-${g.id}'),
          ),
          if (p.done)
            const Text('Reached', key: Key('goal-done'))
          else if (p.projectedDay != null)
            Text(
              'At this pace: ${_day(p.projectedDay!)}'
              '${p.onTrack == null ? '' : p.onTrack! ? ' · On track' : ' · Behind'}',
              key: Key('goal-projection-${g.id}'),
            ),
          if (g.targetDay != null)
            Text(
              'By ${_day(g.targetDay!)}'
              '${p.requiredPerMonthMinor == null ? '' : ' · ${money(p.requiredPerMonthMinor!)} a month'}',
              style: theme.textTheme.bodySmall,
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: Key('goal-contribute-${g.id}'),
              onPressed: onAdd,
              child: const Text('Add money'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundUpCard extends ConsumerWidget {
  const _RoundUpCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(roundUpStepProvider).value ?? 10;
    final goalId = ref.watch(roundUpGoalProvider).value ?? 0;
    final goals = ref.watch(goalProgressListProvider).value ?? const [];
    final r = ref.watch(roundUpThisMonthProvider).value;
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final settings = ref.read(settingsRepositoryProvider);
    final total = r?.totalMinor ?? 0;
    final match = goals.where((g) => g.goal.id == goalId).firstOrNull;
    return AppCard(
      key: const Key('roundup-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Round-ups', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in RoundUp.steps)
                ChoiceChip(
                  key: Key('roundup-step-$s'),
                  label: Text('₹$s'),
                  selected: step == s,
                  onSelected: (_) =>
                      settings.write(GoalSettings.roundUpStep, s),
                ),
            ],
          ),
          if (goals.isNotEmpty)
            DropdownButton<int>(
              key: const Key('roundup-goal'),
              isExpanded: true,
              value: match?.goal.id ?? 0,
              items: [
                const DropdownMenuItem(value: 0, child: Text('No goal')),
                for (final g in goals)
                  DropdownMenuItem(value: g.goal.id, child: Text(g.goal.name)),
              ],
              onChanged: (v) =>
                  settings.write(GoalSettings.roundUpGoal, v ?? 0),
            ),
          const SizedBox(height: 4),
          Text(
            'You could have saved '
            '${formatAmount(total, masked: masked)} this month',
            key: const Key('roundup-total'),
          ),
          Text(
            match == null
                ? 'Pick a goal to track it against.'
                : 'Towards ${match.goal.name}. Nothing is moved.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SalaryCard extends ConsumerStatefulWidget {
  const _SalaryCard();

  @override
  ConsumerState<_SalaryCard> createState() => _SalaryCardState();
}

class _SalaryCardState extends ConsumerState<_SalaryCard> {
  final _s = TextEditingController();
  final _i = TextEditingController();
  final _p = TextEditingController();
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    _s.dispose();
    _i.dispose();
    _p.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final plan = SalaryPlan(
      savingsPct: int.tryParse(_s.text.trim()) ?? -1,
      investPct: int.tryParse(_i.text.trim()) ?? -1,
      spendPct: int.tryParse(_p.text.trim()) ?? -1,
    );
    if (!plan.valid) {
      setState(() => _error = 'Parts must add up to 100');
      return;
    }
    setState(() => _error = null);
    await ref
        .read(settingsRepositoryProvider)
        .write(GoalSettings.salaryPlan, plan.encode());
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(salaryPlanProvider).value ?? SalaryPlan.standard;
    final months = ref.watch(salaryMonthsProvider).value ?? const [];
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    if (!_loaded && ref.watch(salaryPlanProvider).hasValue) {
      _loaded = true;
      _s.text = '${plan.savingsPct}';
      _i.text = '${plan.investPct}';
      _p.text = '${plan.spendPct}';
    }
    String money(int m) => formatAmount(m, masked: masked, paise: false);
    Widget pct(String label, TextEditingController c, Key k) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              key: k,
              controller: c,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '$label %'),
            ),
          ),
        );
    return AppCard(
      key: const Key('salary-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Salary plan', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              pct('Savings', _s, const Key('plan-savings')),
              pct('Invest', _i, const Key('plan-invest')),
              pct('Spend', _p, const Key('plan-spend')),
              TextButton(
                key: const Key('plan-save'),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              key: const Key('plan-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (var k = 0; k < months.length; k++)
            if (months[k].incomeMinor > 0 || k == 0)
              ExpansionTile(
                key: Key('plan-month-$k'),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: k == 0,
                title: Text(
                  () {
                    final d = DateTime.fromMillisecondsSinceEpoch(
                      months[k].monthStartMs + 19800000,
                      isUtc: true,
                    );
                    return '${_mon[d.month - 1]} ${d.year} · income '
                        '${money(months[k].incomeMinor)}';
                  }(),
                ),
                children: [
                  for (final l in SalaryPlanMath.lines(plan, months[k]))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.label),
                      subtitle: Text('Plan ${money(l.plannedMinor)}'),
                      trailing: Text(money(l.actualMinor)),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

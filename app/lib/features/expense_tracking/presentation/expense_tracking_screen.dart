import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/budget_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_math.dart';
import 'package:hisaab/features/expense_tracking/presentation/budget_widgets.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';
import 'package:parser_core/parser_core.dart';

/// Budgets: monthly category limits with progress (F-10, FR-10-09, FR-10-10,
/// FR-10-12). Route `/budgets`.
class ExpenseTrackingScreen extends ConsumerWidget {
  const ExpenseTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final month = ref.watch(budgetMonthProvider);
    final notifier = ref.read(budgetMonthProvider.notifier);
    final uses = ref.watch(budgetUsesProvider(month)).value;
    final alert = ref.watch(budgetAlertPercentProvider).value ??
        BudgetMath.defaultAlertPercent;
    final now = DateTime.now();
    final isCurrent = month.isCurrent(now);
    final lastDay = DateTime(month.start.year, month.start.month + 1, 0).day;
    final daysLeft = isCurrent
        ? BudgetMath.daysLeft(now.year, now.month, now.day)
        : (month.start.isAfter(now) ? lastDay : 0);
    final summary = uses == null
        ? null
        : BudgetSummary(
            lines: uses,
            months: 1,
            alertPercent: alert,
            pace: BudgetMath.paceTick(
              singleCurrentMonth: isCurrent,
              dayOfMonth: now.day,
              lengthOfMonth: lastDay,
            ),
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        key: const Key('budget_add'),
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
        onPressed: () => _edit(context, ref, null, uses ?? const []),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('budget_month_prev'),
                icon: const Icon(Icons.chevron_left),
                onPressed: notifier.previous,
              ),
              Expanded(
                child: Text(
                  month.label,
                  key: const Key('budget_month_label'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('budget_month_next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrent ? null : notifier.next,
              ),
            ],
          ),
          if (summary == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Loading…')),
            )
          else if (summary.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.savings_outlined,
                title: 'No budgets yet',
                hint: 'Set a monthly limit for a category.',
              ),
            )
          else ...[
            _Overview(summary: summary, masked: masked, daysLeft: daysLeft),
            const SizedBox(height: 12),
            for (final u in summary.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BudgetCard(
                  use: u,
                  summary: summary,
                  masked: masked,
                  daysLeft: daysLeft,
                  onEdit: () => _edit(context, ref, u, summary.lines),
                ),
              ),
          ],
          const SizedBox(height: 12),
          _CategorySpend(month: month, masked: masked),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    BudgetUse? existing,
    List<BudgetUse> all,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => BudgetSheet(
          existing: existing,
          taken: {for (final u in all) u.category},
        ),
      );
}

/// Top spend categories of the month (FR-10-01 outflow semantics).
class _CategorySpend extends ConsumerWidget {
  const _CategorySpend({required this.month, required this.masked});

  final MonthRange month;
  final bool masked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spend = ref.watch(monthCategorySpendProvider(month)).value;
    if (spend == null || spend.isEmpty) return const SizedBox.shrink();
    final rows = spend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = rows.fold<int>(0, (s, e) => s + e.value);
    return AppCard(
      key: const Key('spend_by_category'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spent by category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final e in rows.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(e.key.label)),
                  Text(
                    '${formatAmount(e.value, masked: masked, paise: false)}'
                    ' · ${e.value * 100 ~/ total}%',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.summary,
    required this.masked,
    required this.daysLeft,
  });

  final BudgetSummary summary;
  final bool masked;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spent = summary.totalSpentMinor;
    final limit = summary.totalLimitMinor;
    final band = BudgetMath.band(spent, limit, summary.alertPercent);
    return AppCard(
      key: const Key('budget_overview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$daysLeft days left', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '${formatAmount(spent, masked: masked)} of '
            '${formatAmount(limit, masked: masked, paise: false)}',
            key: const Key('budget_overview_text'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _Bar(
            fraction: limit == 0 ? 0 : spent / limit,
            color: bandColor(context, band),
            pace: summary.pace,
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.use,
    required this.summary,
    required this.masked,
    required this.daysLeft,
    required this.onEdit,
  });

  final BudgetUse use;
  final BudgetSummary summary;
  final bool masked;
  final int daysLeft;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = use.category.name;
    final band = BudgetMath.band(
      use.spentMinor,
      use.limitMinor,
      summary.alertPercent,
    );
    final color = bandColor(context, band);
    final daily = BudgetMath.dailyLeft(
      use.limitMinor,
      use.spentMinor,
      daysLeft,
    );
    final String line;
    if (use.spentMinor > use.limitMinor) {
      line = 'Over by ${formatAmount(-use.leftMinor, masked: masked)}';
    } else {
      line = '${formatAmount(use.leftMinor, masked: masked, paise: false)} '
          'left${daily == null ? '' : ' · about '
              '${formatAmount(daily, masked: masked, paise: false)} a day'}';
    }
    return AppCard(
      key: Key('budget_card_$name'),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  use.category.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '${(use.fraction * 100).toInt()}%',
                key: Key('budget_pct_$name'),
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
          Text(
            '${formatAmount(use.spentMinor, masked: masked)} of '
            '${formatAmount(use.limitMinor, masked: masked, paise: false)}',
          ),
          const SizedBox(height: 8),
          _Bar(
            key: Key('budget_bar_$name'),
            fraction: use.fraction,
            color: color,
            pace: summary.pace,
          ),
          const SizedBox(height: 6),
          Text(
            line,
            key: Key('budget_line_$name'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: band == BudgetBand.red ? color : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    this.pace,
    super.key,
  });

  final double fraction;
  final Color color;

  /// Month fraction elapsed (tick), or null.
  final double? pace;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return LayoutBuilder(
      builder: (_, c) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: track,
            ),
          ),
          if (pace != null)
            Positioned(
              left: c.maxWidth * pace!.clamp(0, 1),
              top: 0,
              bottom: 0,
              child: Container(
                key: const Key('budget_pace'),
                width: 2,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}

/// New/Edit budget sheet (FR-10-09). Delete only when editing.
class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({required this.taken, this.existing, super.key});

  final BudgetUse? existing;

  /// Categories that already have a budget.
  final Set<Category> taken;

  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  late Category? _category = widget.existing?.category;
  late final _amount = TextEditingController(
    text:
        widget.existing == null ? '' : '${widget.existing!.limitMinor ~/ 100}',
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final minor = parseRupeesToMinor(_amount.text);
    final options = [
      for (final c in Category.values)
        if (BudgetMath.isBudgetable(c) && !widget.taken.contains(c)) c,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editing ? 'Edit budget' : 'New budget',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (editing)
            Text(_category!.label)
          else
            DropdownButtonFormField<Category>(
              key: const Key('budget_category'),
              initialValue: _category,
              hint: const Text('Category'),
              items: [
                for (final c in options)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() => _category = c),
            ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('budget_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly limit',
              prefixText: '₹ ',
              helperText: 'Applies every month',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (editing)
                TextButton(
                  key: const Key('budget_delete'),
                  onPressed: () async {
                    await ref.read(budgetRepositoryProvider).delete(_category!);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Delete'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('budget_save'),
                onPressed: _category == null || minor == null || minor <= 0
                    ? null
                    : () async {
                        await ref
                            .read(budgetRepositoryProvider)
                            .save(_category!, minor);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/analytics/domain/analytics_view.dart';
import 'package:hisaab/features/analytics/domain/chart_data.dart';
import 'package:parser_core/parser_core.dart';

/// Analysis filters as compact dropdown chips: category cross-filter,
/// account or card scope, period with custom range (FR-18-12, FR-18-27).
/// The account scope is the Book seam (memory 20).
class AnalyticsFilterBar extends ConsumerWidget {
  /// Creates the bar.
  const AnalyticsFilterBar({
    required this.selection,
    required this.onSelect,
    required this.categories,
    super.key,
  });

  /// Current chart selection (its category is the first chip).
  final ChartSelection selection;

  /// Receives the next selection.
  final ValueChanged<ChartSelection> onSelect;

  /// Categories with spend, largest first.
  final List<Category> categories;

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (r == null) return;
    ref.read(periodProvider.notifier).setCustom(r.start, r.end);
    ref
        .read(analyticsPeriodChoiceProvider.notifier)
        .select(AnalyticsPeriod.custom);
  }

  static String _periodLabel(AnalyticsPeriod p) => switch (p) {
        AnalyticsPeriod.thisMonth => 'This month',
        AnalyticsPeriod.lastMonth => 'Last month',
        AnalyticsPeriod.custom => 'Custom',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodChoiceProvider);
    final scope = ref.watch(accountScopeProvider);
    final accounts = ref.watch(analyticsAccountsProvider).value ?? const [];
    final picked = accounts.where((a) => a.id == scope).firstOrNull;
    final cat = selection.category;
    return SingleChildScrollView(
      key: const Key('analytics-filters'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _DropChip<int>(
            chipKey: const Key('analytics-category'),
            label: cat?.label ?? 'By category',
            active: true,
            value: cat == null ? -1 : categories.indexOf(cat),
            options: [-1, for (var i = 0; i < categories.length; i++) i],
            labelOf: (i) => i < 0 ? 'All categories' : categories[i].label,
            onSelected: (i) => onSelect(
              i < 0
                  ? ChartSelection.none
                  : ChartSelection(category: categories[i]),
            ),
          ),
          const SizedBox(width: 8),
          _DropChip<int>(
            chipKey: const Key('analytics-accounts'),
            label: picked == null
                ? 'All accounts'
                : picked.nickname ?? '${picked.bankName} ${picked.last4}',
            value: scope ?? -1,
            options: [-1, for (final a in accounts) a.id],
            labelOf: (id) {
              if (id < 0) return 'All accounts';
              final a = accounts.firstWhere((a) => a.id == id);
              return a.nickname ?? '${a.bankName} ${a.last4}';
            },
            onSelected: (id) =>
                ref.read(accountScopeProvider.notifier).set(id < 0 ? null : id),
          ),
          const SizedBox(width: 8),
          _DropChip<AnalyticsPeriod>(
            chipKey: const Key('analytics-period'),
            label: _periodLabel(period),
            value: period,
            options: AnalyticsPeriod.values,
            labelOf: _periodLabel,
            onSelected: (p) {
              if (p == AnalyticsPeriod.custom) {
                unawaited(_pickRange(context, ref));
              } else {
                ref.read(analyticsPeriodChoiceProvider.notifier).select(p);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Pill that opens a menu of [options]; the first chip is drawn active.
class _DropChip<T> extends StatelessWidget {
  const _DropChip({
    required this.chipKey,
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onSelected,
    this.active = false,
  });

  final Key chipKey;
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      key: chipKey,
      tooltip: '',
      initialValue: value,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<T>(value: o, child: Text(labelOf(o))),
      ],
      child: Container(
        padding: const EdgeInsets.only(left: 14, right: 6, top: 7, bottom: 7),
        decoration: BoxDecoration(
          color: active ? scheme.primaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

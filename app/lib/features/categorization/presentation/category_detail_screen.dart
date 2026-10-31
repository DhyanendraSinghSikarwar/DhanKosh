import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/category_detail_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/categorization/domain/category_detail.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_math.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/charts/bars_chart.dart';
import 'package:hisaab/shared/widgets/charts/chart_card.dart';
import 'package:hisaab/shared/widgets/charts/chart_style.dart';
import 'package:hisaab/shared/widgets/charts/donut_chart.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// `emiLoan` -> `EMI_LOAN`: the stored parent key of a built-in category.
String categoryParentKey(String name) =>
    name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();

/// Category detail: sub-category donut, month trend, top merchants,
/// transactions, budget status and sub-category entry (FR-09-14).
class CategoryDetailScreen extends ConsumerWidget {
  /// Creates the screen for route id [id].
  const CategoryDetailScreen({required this.id, super.key});

  /// `Category.name` or `custom:<n>`.
  final String id;

  Future<void> _addSub(
    BuildContext context,
    WidgetRef ref,
    CategoryDetail d,
  ) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New sub-category'),
        content: TextField(
          key: const Key('subcategory-name'),
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('subcategory-save'),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty) return;
    final parent = d.customCategoryId != null
        ? 'custom:${d.customCategoryId}'
        : categoryParentKey(d.category.name);
    final made = await ref
        .read(categoryRepositoryProvider)
        .addSubcategory(parent: parent, name: name, icon: 'label');
    if (made == null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Already exists')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryDetailProvider(id));
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    String money(int m) => formatAmount(m, masked: masked, paise: false);
    final d = async.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(d == null ? 'Category' : d.category.label),
      ),
      floatingActionButton: d == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              key: const Key('category-add-sub'),
              onPressed: () => _addSub(context, ref, d),
              icon: const Icon(Icons.add),
              label: const Text('Sub-category'),
            ),
      body: d == null
          ? const EmptyState(icon: Icons.category_outlined, title: 'Loading')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                ChartCard(
                  label: 'This month',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        money(d.thisMonth),
                        key: const Key('category-total'),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (d.budgetLimitMinor != null) ...[
                        const SizedBox(height: 12),
                        _Budget(d: d, money: money),
                      ],
                    ],
                  ),
                ),
                if (d.subcategories.isNotEmpty)
                  ChartCard(
                    label: 'Sub-categories',
                    child: _SubDonut(d: d, money: money, masked: masked),
                  ),
                ChartCard(
                  label: 'Last 12 months',
                  child: BarsChart(
                    key: const Key('category-trend'),
                    values: [for (final e in d.monthly) e.$2],
                    color: ChartColors.mint,
                    emphasiseLast: true,
                    masked: masked,
                    xLabels: [
                      for (final (i, e) in d.monthly.indexed)
                        (i, AnalyticsMath.monthLabel(e.$1).substring(0, 1)),
                    ],
                  ),
                ),
                if (d.merchants.isNotEmpty)
                  ChartCard(
                    label: 'Top merchants',
                    child: Column(
                      children: [
                        for (final m in d.merchants)
                          _Line(
                            m.count > 1 ? '${m.name}  ×${m.count}' : m.name,
                            money(m.total),
                          ),
                      ],
                    ),
                  ),
                ChartCard(
                  label: 'Transactions',
                  child: d.txs.isEmpty
                      ? const Text('No transactions')
                      : Column(
                          key: const Key('category-txs'),
                          children: [
                            for (final x in d.txs.take(30))
                              ListTile(
                                key: Key('category-tx-${x.id}'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(x.title),
                                subtitle: Text(
                                  AnalyticsMath.shortDay(dayOf(x.timestamp)),
                                ),
                                trailing: Text(
                                  money(x.inrMinor ?? x.amountMinor),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onTap: () =>
                                    context.push('/transaction/${x.id}'),
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

/// Sub-category donut with a percent legend.
class _SubDonut extends StatelessWidget {
  const _SubDonut({
    required this.d,
    required this.money,
    required this.masked,
  });

  final CategoryDetail d;
  final String Function(int) money;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final total = d.subcategories.fold(0, (a, e) => a + e.$2);
    Color colour(int i) => ChartColors.palette[i % ChartColors.palette.length];
    return Row(
      children: [
        KeyedSubtree(
          key: const Key('category-donut'),
          child: DonutChart(
            parts: [
              for (final (i, s) in d.subcategories.indexed)
                DonutPart(s.$2, colour(i)),
            ],
            centerTop: 'Total',
            centerBottom: compactMoney(total, masked: masked),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              for (final (i, s) in d.subcategories.indexed)
                _Line(
                  s.$1,
                  total == 0 ? '0%' : '${s.$2 * 100 ~/ total}%',
                  dot: colour(i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.dot});

  final String label;
  final String value;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            if (dot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _Budget extends StatelessWidget {
  const _Budget({required this.d, required this.money});

  final CategoryDetail d;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final limit = d.budgetLimitMinor!;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (BudgetMath.ringBand(d.thisMonth, limit)) {
      BudgetBand.red => ChartColors.red,
      BudgetBand.amber => ChartColors.amber,
      BudgetBand.normal => ChartColors.mint,
    };
    return Column(
      key: const Key('category-budget'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: limit <= 0 ? 0 : (d.thisMonth / limit).clamp(0, 1),
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${money(d.thisMonth)} of ${money(limit)} budget',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

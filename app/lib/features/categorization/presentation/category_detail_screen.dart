import 'package:fl_chart/fl_chart.dart';
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
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

const _colors = [
  Color(0xFF2E7D6B),
  Color(0xFF3F6FB5),
  Color(0xFFC77D2B),
  Color(0xFF8A5BB0),
  Color(0xFFC0504D),
  Color(0xFF4C9AA8),
  Color(0xFF9AA03A),
  Color(0xFF7A7F87),
];

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
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(d == null ? 'Category' : d.category.label),
      ),
      floatingActionButton: d == null
          ? null
          : FloatingActionButton.extended(
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
                _Card(
                  title: 'This month',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        money(d.thisMonth),
                        key: const Key('category-total'),
                        style: t.headlineSmall,
                      ),
                      if (d.budgetLimitMinor != null) ...[
                        const SizedBox(height: 8),
                        _Budget(d: d, money: money),
                      ],
                    ],
                  ),
                ),
                if (d.subcategories.isNotEmpty)
                  _Card(
                    title: 'Sub-categories',
                    child: Column(
                      children: [
                        SizedBox(
                          height: 160,
                          child: PieChart(
                            key: const Key('category-donut'),
                            PieChartData(
                              centerSpaceRadius: 46,
                              sectionsSpace: 2,
                              sections: [
                                for (final (i, s) in d.subcategories.indexed)
                                  PieChartSectionData(
                                    value: s.$2.toDouble(),
                                    color: _colors[i % _colors.length],
                                    radius: 26,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        for (final (i, s) in d.subcategories.indexed)
                          _Line(
                            s.$1,
                            money(s.$2),
                            dot: _colors[i % _colors.length],
                          ),
                      ],
                    ),
                  ),
                _Card(
                  title: 'Last 12 months',
                  child: SizedBox(
                    height: 130,
                    child: BarChart(
                      key: const Key('category-trend'),
                      BarChartData(
                        maxY: d.monthly
                                    .fold(0, (a, e) => a > e.$2 ? a : e.$2) ==
                                0
                            ? 1
                            : d.monthly.fold(0, (a, e) => a > e.$2 ? a : e.$2) *
                                1.1,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: const BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(),
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 20,
                              getTitlesWidget: (v, _) => Text(
                                AnalyticsMath.monthLabel(
                                  d.monthly[v.toInt()].$1,
                                ).substring(0, 1),
                                style: t.labelSmall,
                              ),
                            ),
                          ),
                        ),
                        barGroups: [
                          for (final (i, e) in d.monthly.indexed)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: e.$2.toDouble(),
                                  width: 12,
                                  borderRadius: BorderRadius.circular(3),
                                  color: i == d.monthly.length - 1
                                      ? scheme.primary
                                      : scheme.primary.withValues(alpha: 0.4),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (d.merchants.isNotEmpty)
                  _Card(
                    title: 'Top merchants',
                    child: Column(
                      children: [
                        for (final m in d.merchants)
                          _Line('${m.name} (${m.count})', money(m.total)),
                      ],
                    ),
                  ),
                _Card(
                  title: 'Transactions',
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

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.dot});

  final String label;
  final String value;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            if (dot != null) ...[
              Icon(Icons.circle, size: 10, color: dot),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(label)),
            Text(value),
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
      BudgetBand.red => scheme.error,
      BudgetBand.amber => Colors.amber.shade800,
      BudgetBand.normal => scheme.primary,
    };
    return Column(
      key: const Key('category-budget'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: limit <= 0 ? 0 : (d.thisMonth / limit).clamp(0, 1),
          color: color,
        ),
        const SizedBox(height: 4),
        Text('${money(d.thisMonth)} of ${money(limit)} budget'),
      ],
    );
  }
}

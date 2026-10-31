import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:parser_core/parser_core.dart' show Category;

/// Spend by category: donut of the top 7 plus Others, drill into
/// sub-categories on tap (FR-17-11, B5). Includes card purchases.
class HomeCategoriesCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const HomeCategoriesCard({super.key});

  @override
  ConsumerState<HomeCategoriesCard> createState() => _HomeCategoriesCardState();
}

class _HomeCategoriesCardState extends ConsumerState<HomeCategoriesCard> {
  Category? _drill;
  bool _info = false;

  static Color _color(BuildContext c, int i) {
    final s = Theme.of(c).colorScheme;
    final p = [
      s.primary,
      s.tertiary,
      s.secondary,
      const Color(0xFFC9A227),
      const Color(0xFF26A69A),
      const Color(0xFFE57373),
      const Color(0xFF7986CB),
    ];
    return i >= 7 ? s.outline : p[i];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final rows = ref.watch(homeMonthTxsProvider).value;
    if (rows == null) return const SizedBox.shrink();
    final drill = _drill;
    final slices = drill == null
        ? categorySlices(rows.cur)
        : subCategorySlices(rows.cur, drill);
    if (slices.isEmpty) return const SizedBox.shrink();
    final total = slices.fold<int>(0, (s, e) => s + e.amountMinor);
    return AppCard(
      key: const Key('home_categories'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (drill != null)
                IconButton(
                  key: const Key('home_categories_back'),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _drill = null),
                ),
              Expanded(
                child: Text(
                  drill == null ? 'Spend by category' : drill.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('home_categories_info'),
                tooltip: 'About this total',
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: () => setState(() => _info = !_info),
              ),
              TextButton(
                onPressed: () => context.go('/analysis'),
                child: const Text('Trends'),
              ),
            ],
          ),
          if (_info)
            Text(
              'Includes card purchases, so it differs from Spent '
              '(cash basis, ADR-0011).',
              key: const Key('home_categories_note'),
              style: theme.textTheme.bodySmall,
            ),
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (e, r) {
                    final i = r?.touchedSection?.touchedSectionIndex;
                    if (e is FlTapUpEvent && i != null && i >= 0) {
                      _tap(slices[i]);
                    }
                  },
                ),
                sections: [
                  for (final (i, s) in slices.indexed)
                    PieChartSectionData(
                      value: s.amountMinor / 100,
                      color: _color(context, s.label == 'Others' ? 7 : i),
                      radius: 28,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          for (final (i, s) in slices.indexed)
            InkWell(
              key: Key('home_cat_${s.label}'),
              onTap: () => _tap(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: _color(context, s.label == 'Others' ? 7 : i),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.label)),
                    Text('${percentOf(s.amountMinor, total)}%'),
                    const SizedBox(width: 12),
                    Text(
                      formatAmount(s.amountMinor, masked: masked, paise: false),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _tap(CategorySlice s) {
    final c = s.category;
    if (_drill == null && c != null) setState(() => _drill = c);
  }
}

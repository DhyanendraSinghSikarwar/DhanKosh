import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_spent_chart.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';
import 'package:hisaab/shared/widgets/section_label.dart';
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
    const p = [
      AppIcons.mint,
      AppIcons.blue,
      AppIcons.amber,
      AppIcons.violet,
      AppIcons.red,
      AppIcons.teal,
      AppIcons.olive,
    ];
    return i >= 7 ? const Color(0xFF6F7A76) : p[i];
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
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      key: const Key('home_categories'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (drill == null)
            CardHeader(
              'Spend by category',
              info: InfoDot(
                key: const Key('home_categories_info'),
                onTap: () => setState(() => _info = !_info),
              ),
            )
          else
            Row(
              children: [
                InkWell(
                  key: const Key('home_categories_back'),
                  onTap: () => setState(() => _drill = null),
                  child: Text(
                    '‹ All categories',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                SectionLabel(drill.label),
              ],
            ),
          if (_info)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Includes card purchases, so this total differs from Spent '
                'above. Card bill payments are not a category. Tap a '
                'category for its sub-categories.',
                key: const Key('home_categories_note'),
                style:
                    MockText.small(context, color: theme.colorScheme.onSurface),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 48,
                        sectionsSpace: 1.5,
                        startDegreeOffset: -90,
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
                              color:
                                  _color(context, s.label == 'Others' ? 7 : i),
                              radius: 20,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          drill == null
                              ? 'Total'
                              : drill.label.split(' ').first,
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          masked ? '••••' : HomeSpentChart.compact(total / 100),
                          key: const Key('home_categories_centre'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  drill == null
                      ? '${formatAmount(total, masked: masked, paise: false)}'
                          '\nincl. card purchases'
                      : formatAmount(total, masked: masked, paise: false),
                  key: const Key('home_categories_total'),
                  style: MockText.small(context, color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, s) in slices.indexed)
            InkWell(
              key: Key('home_cat_${s.label}'),
              onTap: () => _tap(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _color(context, s.label == 'Others' ? 7 : i),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.label, style: MockText.body(context)),
                    ),
                    if (drill != null) ...[
                      Text(
                        formatAmount(
                          s.amountMinor,
                          masked: masked,
                          paise: false,
                        ),
                        style: MockText.small(context),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      '${percentOf(s.amountMinor, total)}%',
                      style: MockText.body(context)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (drill == null) ...[
                      const SizedBox(width: 10),
                      Text('›', style: MockText.body(context, color: muted)),
                    ],
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

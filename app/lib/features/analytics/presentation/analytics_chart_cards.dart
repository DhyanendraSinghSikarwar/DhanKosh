import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/chart_data.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/analytics/presentation/analytics_card.dart';
import 'package:hisaab/features/analytics/presentation/analytics_cards.dart';
import 'package:hisaab/features/analytics/presentation/charts/chart_legend.dart';
import 'package:hisaab/features/analytics/presentation/charts/chart_style.dart';
import 'package:hisaab/features/analytics/presentation/charts/diverge_bar.dart';
import 'package:hisaab/features/analytics/presentation/charts/donut_chart.dart';
import 'package:hisaab/features/analytics/presentation/charts/fan_chart.dart';
import 'package:hisaab/features/analytics/presentation/charts/line_chart_view.dart';
import 'package:hisaab/features/analytics/presentation/charts/pair_bars_chart.dart';
import 'package:hisaab/features/analytics/presentation/charts/sankey_chart.dart';
import 'package:hisaab/features/analytics/presentation/charts/stacked_bars_chart.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

String _letter(DateTime m) => AnalyticsMath.monthLabel(m).substring(0, 1);

/// Category donut with tap-to-select and sub-category drill-down
/// (FR-18-03, FR-18-29, FR-37-02, FR-37-03).
class CategoryDonutCard extends StatefulWidget {
  /// Creates the card.
  const CategoryDonutCard({
    required this.data,
    required this.txs,
    required this.selection,
    required this.onSelect,
    required this.money,
    this.onOpenCategory,
    this.masked = false,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Period rows (for the sub-category level).
  final List<LedgerTx> txs;

  /// Current selection.
  final ChartSelection selection;

  /// Receives the next selection.
  final ValueChanged<ChartSelection> onSelect;

  /// Opens Category detail for the drilled category.
  final ValueChanged<Category>? onOpenCategory;

  /// Amount formatter.
  final MoneyText money;

  /// Centre figure masked.
  final bool masked;

  @override
  State<CategoryDonutCard> createState() => _CategoryDonutCardState();
}

class _CategoryDonutCardState extends State<CategoryDonutCard> {
  bool _all = false;

  static const _tip = 'Tap a slice to filter merchants. Tap again to clear.';

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final data = widget.data;
    final cat = selection.category;
    final List<(String, int)> rows;
    if (cat != null) {
      rows = ChartData.subcategories(widget.txs, cat);
    } else {
      final top = data.categories.take(7).toList();
      final rest = data.categories.skip(7).fold(0, (a, e) => a + e.$2);
      rows = [
        for (final e in top) (e.$1.label, e.$2),
        if (rest > 0) ('Other', rest),
      ];
    }
    final scheme = Theme.of(context).colorScheme;
    final title = cat == null ? 'By category' : cat.label;
    if (rows.isEmpty) {
      return AnalyticsCard(
        label: title,
        tip: _tip,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No spending'),
            if (cat != null)
              TextButton(
                key: const Key('donut-back'),
                onPressed: () => widget.onSelect(selection.back()),
                child: const Text('Back'),
              ),
          ],
        ),
      );
    }
    final total = rows.fold(0, (a, e) => a + e.$2);
    Color colour(int i) => rows[i].$1 == 'Other' && cat == null
        ? ChartColors.grey
        : ChartColors.palette[i % (ChartColors.palette.length - 1)];
    void tap(int i) {
      if (cat == null) {
        final label = rows[i].$1;
        final c = data.categories
            .where((e) => e.$1.label == label)
            .map((e) => e.$1)
            .firstOrNull;
        if (c != null) widget.onSelect(selection.tapCategory(c));
      } else {
        widget.onSelect(selection.tapSub(rows[i].$1));
      }
    }

    final selIdx = cat == null
        ? -1
        : rows.indexWhere((r) => r.$1 == selection.subcategory);
    final centre = selIdx >= 0 ? rows[selIdx] : null;
    String pct(int v) => '${total == 0 ? 0 : v * 100 ~/ total}%';
    final legend = rows.take(5).toList();
    return AnalyticsCard(
      label: title,
      tip: _tip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cat != null)
            Row(
              children: [
                ActionChip(
                  key: const Key('donut-back'),
                  avatar: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                  onPressed: () => widget.onSelect(selection.back()),
                ),
                const Spacer(),
                if (widget.onOpenCategory != null)
                  TextButton(
                    key: const Key('donut-open'),
                    onPressed: () => widget.onOpenCategory!(cat),
                    child: const Text('Open category'),
                  ),
              ],
            ),
          Row(
            children: [
              KeyedSubtree(
                key: const Key('analytics-donut'),
                child: DonutChart(
                  parts: [
                    for (final (i, r) in rows.indexed)
                      DonutPart(r.$2, colour(i)),
                  ],
                  selected: selIdx >= 0 ? selIdx : null,
                  centerTop:
                      centre == null ? 'Total' : centre.$1.split(' ').first,
                  centerBottom: compactMoney(
                    centre?.$2 ?? total,
                    masked: widget.masked,
                  ),
                  onTap: tap,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final (i, r) in legend.indexed)
                      InkWell(
                        key: Key('donut-row-$i'),
                        onTap: () => tap(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colour(i),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.$1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selection.subcategory == r.$1
                                        ? FontWeight.w700
                                        : null,
                                  ),
                                ),
                              ),
                              Text(
                                pct(r.$2),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (rows.length > 5)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('donut-all'),
                onPressed: () => setState(() => _all = !_all),
                child: Text(_all ? 'Show fewer' : 'All ${rows.length} rows'),
              ),
            ),
          if (_all)
            for (final (i, r) in rows.indexed)
              InkWell(
                key: Key('donut-all-$i'),
                onTap: () => tap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colour(i),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${r.$1} · ${pct(r.$2)}')),
                      Text(
                        widget.money(r.$2),
                        style: TextStyle(color: scheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Last 12 months stacked Essentials, Lifestyle, Other with the average
/// line (FR-18-05, FR-37-04).
class MonthlyTrendCard extends StatefulWidget {
  /// Creates the card.
  const MonthlyTrendCard({
    required this.months,
    required this.money,
    this.filtered = false,
    this.masked = false,
    super.key,
  });

  /// One entry per month, oldest first.
  final List<MonthFlow> months;

  /// Amount formatter.
  final MoneyText money;

  /// Whether a chart selection narrows the bars (ungrouped: all in Other).
  final bool filtered;

  /// Axis labels hidden.
  final bool masked;

  @override
  State<MonthlyTrendCard> createState() => _MonthlyTrendCardState();
}

class _MonthlyTrendCardState extends State<MonthlyTrendCard> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final bars = ChartData.stacked(widget.months);
    final avg = ChartData.averageExcludingLast(bars);
    final picked =
        _picked != null && _picked! < bars.length ? bars[_picked!] : null;
    return AnalyticsCard(
      label: 'Last 12 months',
      tip: 'Essentials, lifestyle, other. Dashed line is the 11-month '
          'average (current month excluded).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: const Key('analytics-trend'),
            child: StackedBarsChart(
              bars: bars,
              labels: [for (final b in bars) _letter(b.month)],
              average: avg,
              picked: _picked,
              masked: widget.masked,
              onPick: (i) => setState(() => _picked = _picked == i ? null : i),
            ),
          ),
          const ChartLegend(
            items: [
              ('Essentials', ChartColors.mint),
              ('Lifestyle', ChartColors.blue),
              ('Other', ChartColors.amber),
            ],
          ),
          if (picked != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: labelRow(
                context,
                '${AnalyticsMath.monthLabel(picked.month)} · '
                '${widget.money(picked.essentials)} / '
                '${widget.money(picked.lifestyle)} / '
                '${widget.money(picked.other)}',
                widget.money(picked.total),
                key: const Key('trend-picked'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Weekday by time-of-day heat grid; tap a cell to filter (FR-18-06,
/// FR-18-29, FR-37-05).
class HeatmapCard extends StatelessWidget {
  /// Creates the card.
  const HeatmapCard({
    required this.heat,
    required this.selection,
    required this.onSelect,
    required this.money,
    super.key,
  });

  /// 7x8 grid, Monday first; columns start at 6a.
  final HeatGrid heat;

  /// Current selection.
  final ChartSelection selection;

  /// Receives the next selection.
  final ValueChanged<ChartSelection> onSelect;

  /// Amount formatter.
  final MoneyText money;

  /// Display order of the data slots: 12a, 3a, 6a, 9a, 12p, 3p, 6p, 9p.
  static const _slotOrder = [6, 7, 0, 1, 2, 3, 4, 5];
  static const _slotText = ['12a', '3a', '6a', '9a', '12p', '3p', '6p', '9p'];
  static const _dayText = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    if (heat.isEmpty) return const SizedBox.shrink();
    final style = ChartStyle.of(context);
    final maxV = heat.fold(0, (a, r) => math.max(a, r.fold(0, math.max)));
    final peak = LedgerMath.heatPeak(heat);
    final d = selection.heatDay;
    final s = selection.heatSlot;
    final muted = TextStyle(color: style.label, fontSize: 12);
    return AnalyticsCard(
      label: 'When you spend',
      tip: 'Darker = more spent. Tap a cell to read its total.',
      child: Column(
        key: const Key('analytics-heat'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 24),
              for (final t in _slotText)
                Expanded(
                  child: Center(
                    child: Text(t,
                        style: TextStyle(color: style.label, fontSize: 10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < 7; r++)
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    _dayText[r],
                    style: TextStyle(color: style.label, fontSize: 10),
                  ),
                ),
                for (final c in _slotOrder)
                  Expanded(
                    child: GestureDetector(
                      key: Key('heat-$r-$c'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(selection.tapHeat(r, c)),
                      child: Container(
                        height: 30,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            style.track,
                            ChartColors.mint,
                            maxV == 0
                                ? 0.0
                                : (heat[r][c] / maxV * 0.9).clamp(0.0, 1.0),
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: d == r && s == c
                              ? Border.all(color: style.fg, width: 2)
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          if (d != null && s != null)
            Text(
              '${LedgerMath.dayLabels[d]} ${LedgerMath.slotLabels[s]}: '
              '${money(heat[d][s])}',
              key: const Key('heat-readout'),
              style: muted,
            )
          else
            Text('Tap a cell', style: muted),
          if (peak != null && !(d != null && s != null))
            Text('Most on ${LedgerMath.peakText(peak)}', style: muted),
        ],
      ),
    );
  }
}

/// Where income went: Sankey from income to the spend groups, investing and
/// saving (FR-18-09).
class IncomeFlowCard extends StatelessWidget {
  /// Creates the card.
  const IncomeFlowCard({
    required this.data,
    required this.money,
    this.masked = false,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  /// Labels masked.
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final s = AnalyticsMath.sankey(data);
    final scheme = Theme.of(context).colorScheme;
    const colours = {
      'Essentials': ChartColors.mint,
      'Lifestyle': ChartColors.blue,
      'Other': ChartColors.grey,
      'Invested': ChartColors.amber,
      'Saved': ChartColors.violet,
    };
    final outs = [
      for (final n in s.outputs)
        if (n.value > 0) (n.label, n.value, colours[n.label]!),
    ];
    final income = s.inputs.fold(0, (a, n) => a + n.value);
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    return AnalyticsCard(
      label: 'Income flow',
      child: Column(
        key: const Key('analytics-flow'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (income == 0 || outs.isEmpty)
            Text(
              'No income recorded this period. Once a salary or other credit '
              'arrives, this shows where it went.',
              style: muted,
            )
          else
            KeyedSubtree(
              key: const Key('analytics-sankey'),
              child: SankeyChart(
                income: income,
                outputs: outs,
                format: (v) => compactMoney(v, masked: masked),
              ),
            ),
          if (s.isShortfall && income > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Spending and investing exceeded income by '
                '${money(s.leftOver)}.',
                style: const TextStyle(color: ChartColors.red, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

/// Income and spend per month, last six months, as paired bars.
class IncomeVsSpendCard extends StatelessWidget {
  /// Creates the card.
  const IncomeVsSpendCard({
    required this.months,
    this.masked = false,
    super.key,
  });

  /// Months, oldest first (the last six are drawn).
  final List<MonthFlow> months;

  /// Axis labels hidden.
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final m = months.length > 6 ? months.sublist(months.length - 6) : months;
    return AnalyticsCard(
      label: 'Income against spend',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: const Key('analytics-income-spend'),
            child: PairBarsChart(
              labels: [for (final e in m) _letter(e.month)],
              income: [for (final e in m) e.income],
              spent: [for (final e in m) e.spent],
              masked: masked,
            ),
          ),
          const ChartLegend(
            items: [
              ('Income', ChartColors.mint),
              ('Spent', ChartColors.red),
            ],
          ),
        ],
      ),
    );
  }
}

/// Savings-rate monthly line with the average (FR-18-11).
class SavingsRateCard extends StatelessWidget {
  /// Creates the card.
  const SavingsRateCard({required this.data, super.key});

  /// Period data.
  final AnalyticsData data;

  static const _mon = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final s = AnalyticsMath.savingsSummary(data.savingsRates);
    final scheme = Theme.of(context).colorScheme;
    if (s == null) {
      return AnalyticsCard(
        label: 'Savings rate',
        child: Text(
          'Needs at least two months with income in the last 12.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      );
    }
    final pts = data.savingsRates;
    final lo = pts.fold<double>(0, (a, p) => math.min(a, p.$2));
    final hi = pts.fold<double>(0, (a, p) => math.max(a, p.$2));
    final top = hi <= 0 ? 24.0 : niceMax(hi);
    final bottom = lo < 0 ? -niceMax(-lo) : 0.0;
    return AnalyticsCard(
      label: 'Savings rate',
      child: Column(
        key: const Key('analytics-savings'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${pts.last.$2.toStringAsFixed(1)}%',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'avg ${s.averagePercent}%',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: const Key('analytics-savings-line'),
            child: LineChartView(
              height: 100,
              minY: bottom,
              maxY: top,
              series: [
                LineSeries(
                  [for (final p in pts) p.$2],
                  ChartColors.violet,
                  endDot: true,
                ),
              ],
              yLabel: (v) => '${v.round()}%',
              xLabels: [
                (0, _mon[pts.first.$1.month - 1]),
                (pts.length - 1, _mon[pts.last.$1.month - 1]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Month-end forecast fan: actual, expected and the low-high band with the
/// budget line (FR-18-13, FR-18-14).
class ForecastCard extends StatelessWidget {
  /// Creates the card.
  const ForecastCard({
    required this.data,
    required this.money,
    this.masked = false,
    super.key,
  });

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  /// Axis labels hidden.
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final f = data.forecast;
    if (f == null) {
      return titledCard(
        context,
        'Forecast',
        const Text('Forecast is for the current month.'),
      );
    }
    final v = f.verdict(data.budget);
    final text = switch (v.kind) {
      ForecastVerdictKind.noBudget => 'No budget set',
      ForecastVerdictKind.within => 'Within budget of ${money(v.budget)}',
      ForecastVerdictKind.over => 'Over budget by ${money(v.overBy)}',
    };
    final scheme = Theme.of(context).colorScheme;
    Widget row(String l, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l,
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
    return AnalyticsCard(
      label: 'Month-end forecast',
      tip: 'Shaded band is the likely range from past months. Dashed line '
          'is the expected path.',
      child: Column(
        key: const Key('analytics-forecast'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: const Key('analytics-fan'),
            child: FanChart(
              actual: f.actual,
              expected: f.expected,
              low: f.low,
              high: f.high,
              budget: data.budget,
              month: f.month,
              masked: masked,
            ),
          ),
          const SizedBox(height: 6),
          row('Expected', money(f.likely)),
          row('Range', '${money(f.lowEnd)} – ${money(f.highEnd)}'),
          row('Bills left', money(f.billsLeft)),
          row(
            'Budget',
            text,
            color: v.kind == ForecastVerdictKind.over ? ChartColors.red : null,
          ),
        ],
      ),
    );
  }
}

/// This period against the previous one by category as diverging bars
/// (FR-18-16).
class CompareCard extends StatelessWidget {
  /// Creates the card.
  const CompareCard({required this.data, required this.money, super.key});

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = data.changes.take(8).toList();
    final fr = ChartData.divergence(rows);
    return AnalyticsCard(
      label: data.isCurrentMonth
          ? 'This month vs last'
          : 'Vs ${data.previousLabel}',
      trailing: Text(
        '${money(data.spent)} vs ${money(data.previousSpent)}',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
      child: Column(
        key: const Key('analytics-compare'),
        children: [
          if (rows.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No spending in either period.'),
            ),
          for (final (i, c) in rows.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      c.category.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: DivergeBar(fraction: fr[i])),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${c.percent > 0 ? '+' : ''}${c.percent}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            c.percent >= 0 ? ChartColors.red : ChartColors.mint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

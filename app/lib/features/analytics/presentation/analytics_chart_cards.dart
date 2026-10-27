import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/chart_data.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/analytics/presentation/analytics_cards.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Category donut with tap-to-select and sub-category drill-down
/// (FR-18-03, FR-18-29, FR-37-02, FR-37-03).
class CategoryDonutCard extends StatelessWidget {
  /// Creates the card.
  const CategoryDonutCard({
    required this.data,
    required this.txs,
    required this.selection,
    required this.onSelect,
    required this.money,
    this.onOpenCategory,
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

  @override
  Widget build(BuildContext context) {
    final cat = selection.category;
    final List<(String, int)> rows;
    if (cat != null) {
      rows = ChartData.subcategories(txs, cat);
    } else {
      final top = data.categories.take(7).toList();
      final rest = data.categories.skip(7).fold(0, (a, e) => a + e.$2);
      rows = [
        for (final e in top) (e.$1.label, e.$2),
        if (rest > 0) ('Other', rest),
      ];
    }
    if (rows.isEmpty) {
      return titledCard(
        context,
        cat == null ? 'By category' : cat.label,
        Column(
          children: [
            const Text('No spending'),
            if (cat != null)
              TextButton(
                key: const Key('donut-back'),
                onPressed: () => onSelect(selection.back()),
                child: const Text('Back'),
              ),
          ],
        ),
      );
    }
    final total = rows.fold(0, (a, e) => a + e.$2);
    void tap(int i) {
      if (cat == null) {
        final label = rows[i].$1;
        final c = data.categories
            .where((e) => e.$1.label == label)
            .map((e) => e.$1)
            .firstOrNull;
        if (c != null) onSelect(selection.tapCategory(c));
      } else {
        onSelect(selection.tapSub(rows[i].$1));
      }
    }

    return titledCard(
      context,
      cat == null ? 'By category' : cat.label,
      Column(
        children: [
          if (cat != null)
            Row(
              children: [
                ActionChip(
                  key: const Key('donut-back'),
                  avatar: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                  onPressed: () => onSelect(selection.back()),
                ),
                const Spacer(),
                if (onOpenCategory != null)
                  TextButton(
                    key: const Key('donut-open'),
                    onPressed: () => onOpenCategory!(cat),
                    child: const Text('Open category'),
                  ),
              ],
            ),
          SizedBox(
            height: 180,
            child: PieChart(
              key: const Key('analytics-donut'),
              PieChartData(
                centerSpaceRadius: 54,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (e, r) {
                    final i = r?.touchedSection?.touchedSectionIndex;
                    if (e is FlTapUpEvent && i != null && i >= 0) tap(i);
                  },
                ),
                sections: [
                  for (final (i, s) in rows.indexed)
                    PieChartSectionData(
                      value: s.$2.toDouble(),
                      color: chartPalette[i % chartPalette.length],
                      radius: selection.subcategory == s.$1 ? 34 : 28,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, s) in rows.indexed)
            InkWell(
              key: Key('donut-row-$i'),
              onTap: () => tap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: chartPalette[i % chartPalette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: labelRow(
                        context,
                        '${s.$1} · ${total == 0 ? 0 : s.$2 * 100 ~/ total}%',
                        money(s.$2),
                        bold: selection.subcategory == s.$1,
                      ),
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

/// 12-month bars stacked Essentials, Lifestyle, Other with the average line
/// (FR-18-05, FR-37-04).
class MonthlyTrendCard extends StatefulWidget {
  /// Creates the card.
  const MonthlyTrendCard({
    required this.months,
    required this.money,
    this.filtered = false,
    super.key,
  });

  /// One entry per month, oldest first.
  final List<MonthFlow> months;

  /// Amount formatter.
  final MoneyText money;

  /// Whether a chart selection narrows the bars (ungrouped: all in Other).
  final bool filtered;

  @override
  State<MonthlyTrendCard> createState() => _MonthlyTrendCardState();
}

class _MonthlyTrendCardState extends State<MonthlyTrendCard> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final bars = ChartData.stacked(widget.months);
    final scheme = Theme.of(context).colorScheme;
    final maxV = bars.fold(0, (a, e) => math.max(a, e.total));
    final avg = ChartData.averageExcludingLast(bars);
    final colors = [scheme.primary, scheme.tertiary, scheme.outline];
    final picked =
        _picked != null && _picked! < bars.length ? bars[_picked!] : null;
    return titledCard(
      context,
      'Monthly trend',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: BarChart(
              key: const Key('analytics-trend'),
              BarChartData(
                maxY: maxV == 0 ? 1 : maxV * 1.1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (_, __, ___, ____) => null,
                  ),
                  touchCallback: (e, r) {
                    final i = r?.spot?.touchedBarGroupIndex;
                    if (e is FlTapUpEvent && i != null) {
                      setState(() => _picked = _picked == i ? null : i);
                    }
                  },
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (avg > 0)
                      HorizontalLine(
                        y: avg.toDouble(),
                        color: scheme.onSurfaceVariant,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                  ],
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) => Text(
                        AnalyticsMath.monthLabel(bars[v.toInt()].month)
                            .substring(0, 1),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (final (i, e) in bars.indexed)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: e.total.toDouble(),
                          width: 14,
                          borderRadius: BorderRadius.circular(3),
                          rodStackItems: [
                            BarChartRodStackItem(
                              0,
                              e.essentials.toDouble(),
                              colors[0],
                            ),
                            BarChartRodStackItem(
                              e.essentials.toDouble(),
                              (e.essentials + e.lifestyle).toDouble(),
                              colors[1],
                            ),
                            BarChartRodStackItem(
                              (e.essentials + e.lifestyle).toDouble(),
                              e.total.toDouble(),
                              colors[2],
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              for (final (i, l) in ['Essentials', 'Lifestyle', 'Other'].indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 10, color: colors[i]),
                    const SizedBox(width: 4),
                    Text(l, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
            ],
          ),
          if (picked != null)
            labelRow(
              context,
              '${AnalyticsMath.monthLabel(picked.month)} · '
              '${widget.money(picked.essentials)} / '
              '${widget.money(picked.lifestyle)} / ${widget.money(picked.other)}',
              widget.money(picked.total),
              key: const Key('trend-picked'),
            ),
          labelRow(context, '11-month average', widget.money(avg)),
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

  /// 7x8 grid, Monday first.
  final HeatGrid heat;
  final ChartSelection selection;
  final ValueChanged<ChartSelection> onSelect;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    if (heat.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final maxV = heat.fold(0, (a, r) => math.max(a, r.fold(0, math.max)));
    final peak = LedgerMath.heatPeak(heat);
    final d = selection.heatDay;
    final s = selection.heatSlot;
    return titledCard(
      context,
      'When you spend',
      Column(
        key: const Key('analytics-heat'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 32),
              for (final l in LedgerMath.slotLabels)
                Expanded(
                  child: Center(
                    child:
                        Text(l, style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < 7; r++)
            Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    LedgerMath.dayLabels[r],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                for (var c = 0; c < 8; c++)
                  Expanded(
                    child: GestureDetector(
                      key: Key('heat-$r-$c'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(selection.tapHeat(r, c)),
                      child: Container(
                        height: 22,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(
                            alpha: maxV == 0
                                ? 0.06
                                : 0.06 + 0.9 * heat[r][c] / maxV,
                          ),
                          borderRadius: BorderRadius.circular(3),
                          border: d == r && s == c
                              ? Border.all(color: scheme.onSurface, width: 2)
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
            )
          else if (peak != null)
            Text('Most on ${LedgerMath.peakText(peak)}'),
        ],
      ),
    );
  }
}

/// Where income went: Sankey from sources to spend groups (FR-18-09).
class IncomeFlowCard extends StatelessWidget {
  /// Creates the card.
  const IncomeFlowCard({required this.data, required this.money, super.key});

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

  @override
  Widget build(BuildContext context) {
    final s = AnalyticsMath.sankey(data);
    final scheme = Theme.of(context).colorScheme;
    final ins = [
      for (final n in s.inputs)
        if (n.value > 0) n,
    ];
    final outs = [
      for (final n in s.outputs)
        if (n.value > 0) n,
      if (s.isShortfall) SankeyNode('Shortfall', s.leftOver),
    ];
    final scale = math.max(
      ins.fold(0, (a, n) => a + n.value),
      outs.fold(0, (a, n) => a + n.value),
    );
    return titledCard(
      context,
      'Where your income went',
      Column(
        key: const Key('analytics-flow'),
        children: [
          if (scale == 0)
            const Text('No income yet')
          else
            SizedBox(
              height: 190,
              child: CustomPaint(
                key: const Key('analytics-sankey'),
                size: Size.infinite,
                painter: SankeyPainter(
                  inputs: [for (final n in ins) (n.label, n.value)],
                  outputs: [for (final n in outs) (n.label, n.value)],
                  scale: scale,
                  colors: chartPalette,
                  textColor: scheme.onSurface,
                  format: money,
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final n in s.outputs) labelRow(context, n.label, money(n.value)),
          labelRow(
            context,
            s.isShortfall ? 'Shortfall' : 'Left over',
            money(s.leftOver),
          ),
        ],
      ),
    );
  }
}

/// Paints left inputs, right outputs and curved ribbons between them.
class SankeyPainter extends CustomPainter {
  /// Creates the painter.
  SankeyPainter({
    required this.inputs,
    required this.outputs,
    required this.scale,
    required this.colors,
    required this.textColor,
    required this.format,
  });

  final List<(String, int)> inputs;
  final List<(String, int)> outputs;
  final int scale;
  final List<Color> colors;
  final Color textColor;
  final String Function(int) format;

  @override
  void paint(Canvas canvas, Size size) {
    const nodeW = 8.0;
    const gap = 6.0;
    final labelW = size.width * 0.28;
    final xl = labelW;
    final xr = size.width - labelW - nodeW;
    double usable(int n) => size.height - gap * (n - 1);
    final inH = [for (final i in inputs) usable(inputs.length) * i.$2 / scale];
    final outH = [
      for (final o in outputs) usable(outputs.length) * o.$2 / scale,
    ];
    var y = 0.0;
    final inY = <double>[];
    for (final h in inH) {
      inY.add(y);
      y += h + gap;
    }
    y = 0;
    final outY = <double>[];
    for (final h in outH) {
      outY.add(y);
      y += h + gap;
    }
    // Ribbons: each input spreads over outputs in proportion.
    final totalIn = inputs.fold(0, (a, e) => a + e.$2);
    final totalOut = outputs.fold(0, (a, e) => a + e.$2);
    final inCursor = [...inY];
    final outCursor = [...outY];
    for (final (i, inp) in inputs.indexed) {
      for (final (o, out) in outputs.indexed) {
        if (totalIn == 0 || totalOut == 0) continue;
        final h1 = inH[i] * (out.$2 / totalOut);
        final h2 = outH[o] * (inp.$2 / totalIn);
        final a = inCursor[i];
        final b = outCursor[o];
        inCursor[i] += h1;
        outCursor[o] += h2;
        final mid = (xl + nodeW + xr) / 2;
        final path = Path()
          ..moveTo(xl + nodeW, a)
          ..cubicTo(mid, a, mid, b, xr, b)
          ..lineTo(xr, b + h2)
          ..cubicTo(mid, b + h2, mid, a + h1, xl + nodeW, a + h1)
          ..close();
        canvas.drawPath(
          path,
          Paint()..color = colors[i % colors.length].withValues(alpha: 0.35),
        );
      }
    }
    void node(
      double x,
      double top,
      double h,
      Color c,
      String label,
      int v, {
      required bool left,
    }) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, nodeW, math.max(h, 2)),
          const Radius.circular(2),
        ),
        Paint()..color = c,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$label\n${format(v)}',
          style: TextStyle(color: textColor, fontSize: 10, height: 1.2),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        textAlign: left ? TextAlign.right : TextAlign.left,
      )..layout(maxWidth: labelW - 6);
      final dx = left ? x - 4 - tp.width : x + nodeW + 4;
      tp.paint(canvas, Offset(dx, top + math.max(h, 2) / 2 - tp.height / 2));
    }

    for (final (i, e) in inputs.indexed) {
      node(
        xl - 0,
        inY[i],
        inH[i],
        colors[i % colors.length],
        e.$1,
        e.$2,
        left: true,
      );
    }
    for (final (o, e) in outputs.indexed) {
      node(
        xr,
        outY[o],
        outH[o],
        colors[(o + 3) % colors.length],
        e.$1,
        e.$2,
        left: false,
      );
    }
  }

  @override
  bool shouldRepaint(SankeyPainter old) =>
      old.inputs != inputs || old.outputs != outputs || old.scale != scale;
}

/// Savings-rate monthly line with the average (FR-18-11).
class SavingsRateCard extends StatelessWidget {
  /// Creates the card.
  const SavingsRateCard({required this.data, super.key});

  /// Period data.
  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final s = AnalyticsMath.savingsSummary(data.savingsRates);
    if (s == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final pts = data.savingsRates;
    return titledCard(
      context,
      'Savings rate',
      Column(
        children: [
          if (pts.length >= 2)
            SizedBox(
              height: 110,
              child: LineChart(
                key: const Key('analytics-savings-line'),
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: s.averagePercent.toDouble(),
                        color: scheme.onSurfaceVariant,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                      HorizontalLine(y: 0, color: scheme.outlineVariant),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (final (i, p) in pts.indexed)
                          FlSpot(i.toDouble(), p.$2),
                      ],
                      color: scheme.primary,
                      isCurved: true,
                      dotData: FlDotData(
                        checkToShowDot: (spot, _) => spot.x == pts.length - 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          labelRow(
            context,
            AnalyticsMath.monthLabel(s.latestMonth),
            '${s.latestPercent}%',
          ),
          labelRow(
            context,
            'Average of ${s.months} months',
            '${s.averagePercent}%',
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
  const ForecastCard({required this.data, required this.money, super.key});

  /// Period data.
  final AnalyticsData data;

  /// Amount formatter.
  final MoneyText money;

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
    return titledCard(
      context,
      'Month-end forecast',
      Column(
        key: const Key('analytics-forecast'),
        children: [
          SizedBox(
            height: 150,
            child: CustomPaint(
              key: const Key('analytics-fan'),
              size: Size.infinite,
              painter: FanPainter(
                actual: f.actual,
                expected: f.expected,
                low: f.low,
                high: f.high,
                budget: data.budget,
                line: scheme.primary,
                band: scheme.primary.withValues(alpha: 0.18),
                budgetColor: scheme.error,
              ),
            ),
          ),
          labelRow(context, 'Likely', money(f.likely)),
          labelRow(
            context,
            'Range',
            '${money(f.lowEnd)} – ${money(f.highEnd)}',
          ),
          labelRow(context, 'Bills left', money(f.billsLeft)),
          Text(text),
        ],
      ),
    );
  }
}

/// Paints the forecast fan (FR-18-13).
class FanPainter extends CustomPainter {
  /// Creates the painter.
  FanPainter({
    required this.actual,
    required this.expected,
    required this.low,
    required this.high,
    required this.budget,
    required this.line,
    required this.band,
    required this.budgetColor,
  });

  final List<int> actual;
  final List<int> expected;
  final List<int> low;
  final List<int> high;
  final int budget;
  final Color line;
  final Color band;
  final Color budgetColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(expected.length, math.max(actual.length, 2));
    final maxV = [
      budget,
      ...high,
      ...expected,
      ...actual,
      1,
    ].reduce(math.max).toDouble();
    Offset pt(int i, int v) =>
        Offset(size.width * i / (n - 1), size.height * (1 - v / maxV));
    final from = actual.isEmpty ? 0 : actual.length - 1;
    if (high.length > from && low.length > from) {
      final path = Path()
        ..moveTo(pt(from, high[from]).dx, pt(from, high[from]).dy);
      for (var i = from + 1; i < high.length; i++) {
        final p = pt(i, high[i]);
        path.lineTo(p.dx, p.dy);
      }
      for (var i = low.length - 1; i >= from; i--) {
        final p = pt(i, low[i]);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), Paint()..color = band);
    }
    Path series(List<int> l, int start) {
      final p = Path();
      for (var i = start; i < l.length; i++) {
        final o = pt(i, l[i]);
        i == start ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (actual.length > 1) canvas.drawPath(series(actual, 0), stroke);
    if (expected.length > from + 1) {
      canvas.drawPath(
        series(expected, from),
        stroke..color = line.withValues(alpha: 0.6),
      );
    }
    if (budget > 0) {
      final y = size.height * (1 - budget / maxV);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = budgetColor
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(FanPainter old) =>
      old.expected != expected || old.actual != actual || old.budget != budget;
}

/// Change versus the previous period by category as diverging bars
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
    final rows = data.changes.take(10).toList();
    final fr = ChartData.divergence(rows);
    return titledCard(
      context,
      'Versus ${data.previousLabel}',
      Column(
        key: const Key('analytics-compare'),
        children: [
          labelRow(context, 'This period', money(data.spent)),
          labelRow(context, 'Previous', money(data.previousSpent)),
          const Divider(),
          for (final (i, c) in rows.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child:
                        Text(c.category.label, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 12,
                      child: CustomPaint(
                        painter: _DivergePainter(
                          fr[i],
                          fr[i] > 0 ? scheme.error : scheme.primary,
                          scheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${c.percent > 0 ? '+' : ''}${c.percent}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: c.percent > 0 ? scheme.error : scheme.primary,
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

class _DivergePainter extends CustomPainter {
  _DivergePainter(this.f, this.color, this.axis);

  final double f;
  final Color color;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    canvas.drawLine(
      Offset(mid, 0),
      Offset(mid, size.height),
      Paint()..color = axis,
    );
    final w = mid * f.abs();
    canvas.drawRect(
      f >= 0
          ? Rect.fromLTWH(mid, 2, w, size.height - 4)
          : Rect.fromLTWH(mid - w, 2, w, size.height - 4),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DivergePainter old) => old.f != f || old.color != color;
}

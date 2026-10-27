import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_charts.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_summary.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Colour of an asset class.
Color assetClassColor(AssetClass c, ColorScheme s) => switch (c) {
      AssetClass.equity => s.primary,
      AssetClass.retirement => s.tertiary,
      AssetClass.debt => s.secondary,
      AssetClass.gold => const Color(0xFFC9A227),
      AssetClass.cash => const Color(0xFF26A69A),
      AssetClass.other => s.outline,
    };

/// Asset allocation donut with a class filter (FR-16-02, B8). Choosing a
/// class shows that class's holdings.
class AllocationCard extends StatefulWidget {
  /// Creates the card.
  const AllocationCard({
    required this.summary,
    required this.holdings,
    required this.money,
    required this.asOfLabel,
    super.key,
  });

  final PortfolioSummary summary;
  final List<Holding> holdings;
  final String Function(int) money;

  /// `as of ...` text, empty when unknown.
  final String asOfLabel;

  @override
  State<AllocationCard> createState() => _AllocationCardState();
}

class _AllocationCardState extends State<AllocationCard> {
  AssetClass? _only;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final classes = allocationShares(widget.summary.byClass, widget.holdings);
    final shares = allocationShares(
      widget.summary.byClass,
      widget.holdings,
      only: _only,
    );
    final total = shares.fold<int>(0, (a, e) => a + e.amountMinor);
    Color colorOf(int i, ChartShare s) => s.assetClass != null && _only == null
        ? assetClassColor(s.assetClass!, scheme)
        : Color.lerp(
            assetClassColor(_only ?? AssetClass.other, scheme),
            scheme.surface,
            (i * 0.12).clamp(0, 0.7),
          )!;
    return AppCard(
      key: const Key('allocation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Allocation', style: theme.textTheme.titleSmall),
          if (widget.asOfLabel.isNotEmpty)
            Text(
              widget.asOfLabel,
              key: const Key('allocation-as-of'),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const Key('alloc-filter-all'),
                label: const Text('All'),
                selected: _only == null,
                onSelected: (_) => setState(() => _only = null),
              ),
              for (final c in classes)
                ChoiceChip(
                  key: Key('alloc-filter-${c.assetClass!.name}'),
                  label: Text(c.label),
                  selected: _only == c.assetClass,
                  onSelected: (_) => setState(() => _only = c.assetClass),
                ),
            ],
          ),
          if (total > 0) ...[
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final (i, s) in shares.indexed)
                      PieChartSectionData(
                        value: s.amountMinor / 100,
                        color: colorOf(i, s),
                        radius: 28,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            for (final (i, e) in shares.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: colorOf(i, e)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.label)),
                    Text('${(e.amountMinor * 100 / total).round()}%'),
                    const SizedBox(width: 12),
                    Text(widget.money(e.amountMinor)),
                  ],
                ),
              ),
          ],
          if (widget.summary.investedMinor > 0) ...[
            const Divider(),
            Text(
              'Invested ${widget.money(widget.summary.investedMinor)}  ·  Gain '
              '${widget.summary.gainMinor < 0 ? '-' : '+'}'
              '${widget.money(widget.summary.gainMinor.abs())}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

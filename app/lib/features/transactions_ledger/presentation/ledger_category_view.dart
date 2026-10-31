import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_views.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_category_style.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_tx_tile.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';

/// Spends by category: donut, then a row per category with an
/// account / card-purchase bar (FR-08-23, ADR-0011); a row expands to its
/// transactions.
class LedgerCategoryView extends StatefulWidget {
  /// Creates the view over [rows].
  const LedgerCategoryView({
    required this.rows,
    required this.masked,
    required this.rowBuilder,
    super.key,
  });

  /// Rows to group (period and filters already applied).
  final List<LedgerTx> rows;

  /// Hide-amounts setting.
  final bool masked;

  /// Builds a tile for one row.
  final Widget Function(LedgerTx) rowBuilder;

  @override
  State<LedgerCategoryView> createState() => _LedgerCategoryViewState();
}

class _LedgerCategoryViewState extends State<LedgerCategoryView> {
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final groups =
        groupByCategory(widget.rows).where((g) => g.totalMinor > 0).toList();
    String amt(int v) => formatAmount(v, masked: widget.masked, paise: false);
    final total = groups.fold<int>(0, (s, g) => s + g.totalMinor);
    final top = groups.isEmpty ? 1 : groups.first.totalMinor;
    return AppCard(
      key: const Key('category_card'),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            width: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 46,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(enabled: false),
                    sections: [
                      for (final (i, g) in groups.indexed)
                        PieChartSectionData(
                          value: g.totalMinor.toDouble(),
                          color: rankColor(context, i),
                          radius: 24,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total', style: theme.textTheme.labelSmall),
                    Text(
                      compactAmount(total, masked: widget.masked),
                      key: const Key('category_total'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, g) in groups.indexed) ...[
            InkWell(
              key: Key('category_${g.category.name}'),
              onTap: () => setState(() {
                if (!_open.remove(g.category.name)) _open.add(g.category.name);
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rankColor(context, i),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            g.category.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          amt(g.totalMinor),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _SplitBar(
                      key: Key('category_bar_${g.category.name}'),
                      share: g.totalMinor / top,
                      accountMinor: g.accountMinor,
                      cardMinor: g.cardMinor,
                      color: rankColor(context, i),
                    ),
                  ],
                ),
              ),
            ),
            if (_open.contains(g.category.name)) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  [
                    if (g.accountMinor != 0) 'Account ${amt(g.accountMinor)}',
                    if (g.cardMinor != 0) 'Card ${amt(g.cardMinor)}',
                  ].join(' · '),
                  key: Key('category_split_${g.category.name}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              ...withDividers([for (final t in g.rows) widget.rowBuilder(t)]),
            ],
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 14,
              children: [
                _LegendDot('Account', AppIcons.mint, theme),
                _LegendDot('Card purchases', AppIcons.violet, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color, this.theme);
  final String label;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
}

/// Track with the account share in the category colour and the card share in
/// violet; the filled part is [share] of the track.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.share,
    required this.accountMinor,
    required this.cardMinor,
    required this.color,
    super.key,
  });

  final double share;
  final int accountMinor;
  final int cardMinor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final acc = accountMinor < 0 ? 0 : accountMinor;
    final card = cardMinor < 0 ? 0 : cardMinor;
    final sum = acc + card;
    final accFlex = sum == 0 ? 1 : (acc * 1000 ~/ sum);
    final cardFlex = sum == 0 ? 0 : 1000 - accFlex;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 9,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: share.clamp(0.02, 1),
          child: Row(
            children: [
              if (accFlex > 0)
                Expanded(
                  flex: accFlex,
                  child: Container(color: color),
                ),
              if (cardFlex > 0)
                Expanded(
                  flex: cardFlex,
                  child: Container(
                    color: AppIcons.violet.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

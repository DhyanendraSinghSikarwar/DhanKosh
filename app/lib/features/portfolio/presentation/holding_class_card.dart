import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_charts.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_class.dart';
import 'package:hisaab/features/portfolio/presentation/holding_labels.dart';
import 'package:hisaab/features/portfolio/presentation/holding_spark.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_class_style.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';

/// One card per asset class: header with value and return, an optional
/// note, and a row per holding (FR-16-41).
class HoldingClassCard extends StatelessWidget {
  /// Creates the card.
  const HoldingClassCard({
    required this.group,
    required this.money,
    required this.onTap,
    required this.dateLabel,
    super.key,
  });

  final ClassGroup group;
  final String Function(int) money;
  final void Function(Holding) onTap;

  /// `d MMM yyyy` of an epoch ms.
  final String Function(int) dateLabel;

  String? _note() => switch (group.cls) {
        PortfolioClass.sukanya => 'Yearly deposit limit ${money(15000000)}',
        PortfolioClass.epfo
            when group.items.any((h) => h.source != HoldingSource.manual) =>
          'From passbook SMS and mail',
        _ => _newest > 0 ? 'as of ${dateLabel(_newest)}' : null,
      };

  /// Newest statement date in the group; the header shows it once.
  int get _newest => group.items.fold<int>(
        0,
        (a, h) => (h.asOf ?? 0) > a ? h.asOf! : a,
      );

  /// True when [h] was stated more than a day before the group's newest.
  bool _stale(Holding h) => h.asOf != null && h.asOf! < _newest - 86400000;

  String _sub(Holding h) {
    final u = h.units;
    final units = u == null
        ? null
        : '${u == u.roundToDouble() ? u.round() : u.toStringAsFixed(2)} '
            '${h.kind == HoldingKind.stock ? 'shares' : 'units'}';
    return [
      if (units != null) units,
      if (group.cls == PortfolioClass.other || h.kind == HoldingKind.etf)
        holdingKindLabel(h.kind),
      if (units == null && h.investedMinor != null)
        'Invested ${money(h.investedMinor!)}',
    ].join(' · ');
  }

  Widget _row(BuildContext context, Holding h, SemanticColors sem) {
    final theme = Theme.of(context);
    final pct = h.returnPct;
    return InkWell(
      key: Key('holding-${h.id}'),
      onTap: () => onTap(h),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                h.name.trim().isEmpty ? '?' : h.name.trim()[0].toUpperCase(),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    _sub(h) +
                        (_stale(h)
                            ? '${_sub(h).isEmpty ? '' : ' · '}'
                                'as of ${dateLabel(h.asOf!)}'
                            : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HoldingSpark(
              key: Key('spark-${h.id}'),
              values: holdingSpark(h),
              color: portfolioClassColor(group.cls),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(h.valueMinor ?? 0)),
                  if (pct != null)
                    Text(
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: pct >= 0 ? sem.income : sem.expense,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    final pct = group.returnPct;
    final note = _note();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        key: Key('class-card-${group.cls.name}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(portfolioClassIcon(group.cls), size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.cls.label,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(group.valueMinor),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (pct != null)
                      Text(
                        '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: pct >= 0 ? sem.income : sem.expense,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            for (final h in group.items) _row(context, h, sem),
          ],
        ),
      ),
    );
  }
}

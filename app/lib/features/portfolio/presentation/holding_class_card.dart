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
        _ => null,
      };

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
                      style: theme.textTheme.titleSmall,
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
            for (final h in group.items)
              ListTile(
                key: Key('holding-${h.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  h.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (group.cls == PortfolioClass.other ||
                        h.kind == HoldingKind.etf)
                      holdingKindLabel(h.kind),
                    if (h.investedMinor != null)
                      'Invested ${money(h.investedMinor!)}',
                    if (h.asOf != null) 'as of ${dateLabel(h.asOf!)}',
                  ].join(' · '),
                ),
                leading: HoldingSpark(
                  key: Key('spark-${h.id}'),
                  values: holdingSpark(h),
                  color: (h.valueMinor ?? 0) >= (h.previousValueMinor ?? 0)
                      ? sem.income
                      : sem.expense,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money(h.valueMinor ?? 0)),
                    if (h.returnPct != null)
                      Text(
                        '${h.returnPct! >= 0 ? '+' : ''}'
                        '${h.returnPct!.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: h.returnPct! >= 0 ? sem.income : sem.expense,
                        ),
                      ),
                  ],
                ),
                onTap: () => onTap(h),
              ),
          ],
        ),
      ),
    );
  }
}

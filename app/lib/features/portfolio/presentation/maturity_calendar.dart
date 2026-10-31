import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/portfolio/domain/maturity_items.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_charts.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

/// Deposits maturing in the next 12 months, grouped by month (FR-16-12).
class MaturityCalendar extends StatelessWidget {
  /// Creates the calendar.
  const MaturityCalendar({required this.items, super.key});

  final List<MaturityItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    final groups = maturityByMonth(items);
    return AppCard(
      key: const Key('maturities'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Upcoming maturities'),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No deposits maturing in 12 months'),
            ),
          for (final e in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(e.key, style: theme.textTheme.labelMedium),
            ),
            for (final m in e.value)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(m.name)),
                    Text(
                      m.daysLeft == 0 ? 'Today' : 'in ${m.daysLeft} d',
                      style: TextStyle(color: m.soon ? sem.warning : null),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

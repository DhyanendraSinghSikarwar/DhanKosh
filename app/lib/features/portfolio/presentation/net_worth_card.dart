import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/presentation/net_worth_chart.dart';
import 'package:hisaab/features/portfolio/presentation/section_info_label.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/pill_tabs.dart';

/// Range tab labels (FR-16-05) and the phrase after the change figure.
const netWorthRanges = ['1M', '6M', '1Y', '3Y', 'All'];
const _rangeWords = [
  'this month',
  'in 6 months',
  'this year',
  'in 3 years',
  'all time',
];

/// Full-width net worth card: value, change, range pills, history line and
/// the Investments / Bank / Loans row (FR-16-01, FR-16-05).
class NetWorthCard extends StatelessWidget {
  /// Creates the card.
  const NetWorthCard({
    required this.net,
    required this.points,
    required this.range,
    required this.onRange,
    required this.investments,
    required this.bank,
    required this.loans,
    required this.money,
    required this.asOf,
    this.masked = false,
    super.key,
  });

  final int net;

  /// Points inside the range, oldest first.
  final List<WorthPoint> points;
  final int range;
  final ValueChanged<int> onRange;
  final int investments;
  final int bank;
  final int loans;
  final String Function(int) money;
  final String asOf;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    final muted = theme.colorScheme.onSurfaceVariant;
    final change =
        points.length < 2 ? null : points.last.netMinor - points.first.netMinor;
    Widget cell(String label, String value, CrossAxisAlignment a,
            {Color? color, Key? key}) =>
        Column(
          crossAxisAlignment: a,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 2),
            Text(
              value,
              key: key,
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        );
    return AppCard(
      key: const Key('networth-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionInfoLabel(
            'Net worth',
            tip: 'Investments + bank balances - loans - card dues. Values '
                'come from statements and passbook messages; estimates are '
                'marked.',
          ),
          const SizedBox(height: 6),
          Text(
            money(net),
            key: const Key('nw-value'),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
          ),
          if (change != null)
            Text(
              '${change >= 0 ? '▲' : '▼'} ${money(change.abs())} '
              '${_rangeWords[range]}',
              key: const Key('nw-change'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: change >= 0 ? sem.income : sem.expense),
            ),
          const SizedBox(height: 12),
          PillTabs(
            keyPrefix: 'range',
            labels: netWorthRanges,
            selected: range,
            onChanged: onRange,
          ),
          const SizedBox(height: 12),
          NetWorthChart(points: points, masked: masked),
          Text(
            'as of $asOf',
            key: const Key('nw-as-of'),
            style: TextStyle(fontSize: 11, color: muted),
          ),
          const Divider(height: 24),
          Row(
            key: const Key('nw-summary'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              cell('Investments', money(investments), CrossAxisAlignment.start),
              cell('Bank', money(bank), CrossAxisAlignment.start),
              cell(
                'Loans',
                loans > 0 ? '-${money(loans)}' : money(0),
                CrossAxisAlignment.end,
                color: loans > 0 ? sem.expense : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

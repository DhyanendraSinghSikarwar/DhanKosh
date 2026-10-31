import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Open loans: total outstanding and next EMI, with a row per loan when
/// there is more than one; opens Loans (C10).
class PortfolioLoansSection extends StatelessWidget {
  /// Creates the section.
  const PortfolioLoansSection({
    required this.loans,
    required this.money,
    super.key,
  });

  final List<Loan> loans;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final open = [
      for (final l in loans)
        if (!l.closed) l,
    ];
    final outstanding =
        open.fold<int>(0, (a, l) => a + (l.outstandingMinor ?? 0));
    final due = [
      for (final l in open)
        if (l.nextDue != null) l,
    ]..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));
    final next = due.isEmpty ? null : due.first;
    return AppCard(
      key: const Key('portfolio-loans'),
      onTap: () => context.push('/loans'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: SectionLabel('Loans')),
              Icon(Icons.chevron_right, size: 20),
            ],
          ),
          if (open.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No open loans'),
            )
          else ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        money(outstanding),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        'Outstanding',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                if (next?.emiMinor != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(next!.emiMinor!),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        'Next EMI ${next.nextDue!.day} '
                        '${_months[next.nextDue!.month - 1]}',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          if (open.length > 1)
            for (final l in open)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      [
                        if (l.outstandingMinor != null)
                          money(l.outstandingMinor!),
                        if (l.emiMinor != null) 'EMI ${money(l.emiMinor!)}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

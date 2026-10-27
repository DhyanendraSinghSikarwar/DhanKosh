import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Open loans with outstanding and EMI; opens Loans (C10).
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
    final open = [
      for (final l in loans)
        if (!l.closed) l,
    ];
    return AppCard(
      key: const Key('portfolio-loans'),
      onTap: () => context.push('/loans'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Loans', style: theme.textTheme.titleSmall)),
              const Icon(Icons.chevron_right),
            ],
          ),
          if (open.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No open loans'),
            ),
          for (final l in open)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// `5 Oct 2026`.
String loanDate(DateTime d) {
  const m = [
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
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// One loan: outstanding, EMI, next due and progress (FR-15-04, FR-15-07).
class LoanCard extends StatelessWidget {
  /// Creates the card.
  const LoanCard({
    required this.loan,
    required this.masked,
    required this.onTap,
    super.key,
  });

  /// The loan.
  final Loan loan;

  /// Hide-amounts state.
  final bool masked;

  /// Opens the detail.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String money(int? m) =>
        m == null ? '-' : formatAmount(m, masked: masked, paise: false);
    final p = loan.progress;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(loan.name, style: text.titleMedium)),
              if (loan.detected) const Chip(label: Text('Detected')),
              if (loan.closed) const Chip(label: Text('Closed')),
            ],
          ),
          const SizedBox(height: 4),
          Text('Outstanding', style: text.labelMedium),
          Text(money(loan.outstandingMinor), style: text.headlineSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('EMI ${money(loan.emiMinor)}')),
              Text(
                loan.nextDue == null
                    ? 'No due date'
                    : 'Next ${loanDate(loan.nextDue!)}',
              ),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: p),
            const SizedBox(height: 4),
            Text(
              '${(p * 100).round()}% repaid'
              '${loan.totalEmis == null ? '' : ' · ${loan.paidCount}/${loan.totalEmis} EMIs'}',
              style: text.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/loans/domain/loan_builder.dart';
import 'package:hisaab/features/loans/domain/loan_link_repository.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/features/loans/presentation/loan_card.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';

/// Pick a payment to count towards [loan] (FR-15-10). Needs a loan account.
class LinkPaymentSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const LinkPaymentSheet({required this.loan, super.key});

  /// Target loan (has an account id).
  final Loan loan;

  @override
  ConsumerState<LinkPaymentSheet> createState() => _LinkPaymentSheetState();
}

class _LinkPaymentSheetState extends ConsumerState<LinkPaymentSheet> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(planWindowProvider).value ?? const [];
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final have = {for (final p in widget.loan.payments) p.id};
    final rows = [
      for (final t in txs)
        if (Loans.isPayment(t) && !have.contains(t.id)) t,
    ].take(40).toList();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Link a payment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            key: const Key('link-all'),
            title: const Text('Link all from this payee'),
            value: _all,
            onChanged: (v) => setState(() => _all = v),
          ),
          Flexible(
            child: rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No payments to link'),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final t in rows)
                        ListTile(
                          key: Key('link-${t.id}'),
                          title: Text(t.title),
                          subtitle: Text(
                            loanDate(Ist.dateOf(t.timestamp)),
                          ),
                          trailing: Text(
                            formatAmount(
                              t.amountMinor,
                              masked: masked,
                              paise: false,
                            ),
                          ),
                          onTap: () async {
                            final repo = ref.read(loanLinkRepositoryProvider);
                            final key = LoanLinkSet.keyOf(t.merchant, t.upiId);
                            final id = widget.loan.accountId!;
                            if (_all && key.isNotEmpty) {
                              await repo.linkPayee(key, id);
                            } else {
                              await repo.linkTx(t.id, id);
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

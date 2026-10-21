import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/loans/domain/amortization.dart';
import 'package:hisaab/features/loans/domain/loan_link_repository.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/features/loans/presentation/link_payment_sheet.dart';
import 'package:hisaab/features/loans/presentation/loan_card.dart';
import 'package:hisaab/features/loans/presentation/loan_form_sheet.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// One loan: summary, payoff projection, schedule and payments
/// (FR-15-05, FR-15-07, FR-15-10, FR-15-11). Route `/loans/:key`.
class LoanDetailScreen extends ConsumerWidget {
  /// Creates the screen for the loan with [loanKey].
  const LoanDetailScreen({required this.loanKey, super.key});

  /// `acct:<id>` or `payee:<key>`.
  final String loanKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loansStateProvider);
    final links = ref.watch(loanLinkSetProvider).value ?? const LoanLinkSet();
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final loan = state.value?.loans.where((l) => l.key == loanKey).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(loan?.name ?? 'Loan'),
        actions: [
          if (loan?.accountId != null)
            IconButton(
              key: const Key('loan-edit'),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => LoanFormSheet(loan: loan),
              ),
            ),
        ],
      ),
      body: loan == null
          ? Center(
              child: state.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Loan not found'),
            )
          : _Body(loan: loan, links: links, masked: masked),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.loan, required this.links, required this.masked});

  final Loan loan;
  final LoanLinkSet links;
  final bool masked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    String money(int? m) =>
        m == null ? '-' : formatAmount(m, masked: masked, paise: false);
    final repo = ref.read(loanLinkRepositoryProvider);
    final t = loan.terms;
    final schedule = t == null
        ? const <Instalment>[]
        : Amortization.schedule(t, emiMinor: loan.emiMinor);
    Widget kv(String k, String v, [Key? key]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(k)),
              Text(v, key: key, style: text.titleSmall),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LoanCard(loan: loan, masked: masked, onTap: () {}),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              kv(
                  'Source',
                  switch (loan.outstandingSource) {
                    OutstandingSource.bank => 'Bank balance',
                    OutstandingSource.schedule => 'Schedule',
                    OutstandingSource.none => 'Unknown',
                  }),
              kv('Paid so far', money(loan.totalPaidMinor)),
              kv('Remaining EMIs', '${loan.remainingEmis ?? '-'}',
                  const Key('loan-remaining')),
              kv(
                'Payoff',
                loan.payoffDate == null ? '-' : loanDate(loan.payoffDate!),
                const Key('loan-payoff'),
              ),
              if (loan.totalInterestMinor != null)
                kv('Total interest', money(loan.totalInterestMinor)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            if (loan.accountId != null)
              OutlinedButton(
                key: const Key('loan-link'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => LinkPaymentSheet(loan: loan),
                ),
                child: const Text('Link payment'),
              ),
            if (loan.detected)
              OutlinedButton(
                key: const Key('loan-dismiss'),
                onPressed: () async {
                  await repo.dismissPayee(loan.key.substring('payee:'.length));
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Not a loan'),
              ),
          ],
        ),
        if (schedule.isNotEmpty)
          ExpansionTile(
            key: const Key('loan-schedule'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Schedule'),
            children: [
              for (final i in schedule)
                ListTile(
                  key: Key('inst-${i.number}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    i.number <= loan.paidCount
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
                  title: Text(
                    '#${i.number}  ${i.due == null ? '' : loanDate(i.due!)}',
                  ),
                  subtitle: Text(
                    'Interest ${money(i.interestMinor)} · '
                    'Principal ${money(i.principalMinor)}',
                  ),
                  trailing: Text(money(i.emiMinor)),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Text('Payments', style: text.titleSmall),
        if (loan.payments.isEmpty) const Text('None yet'),
        for (final p in loan.payments.take(30))
          ListTile(
            key: Key('pay-${p.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(p.title),
            subtitle: Text(loanDate(Ist.dateOf(p.timestamp))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(money(p.amountMinor)),
                if (links.tx.containsKey(p.id) ||
                    links.payee.containsKey(
                      LoanLinkSet.keyOf(p.merchant, p.upiId),
                    ))
                  IconButton(
                    key: Key('unlink-${p.id}'),
                    tooltip: 'Unlink',
                    icon: const Icon(Icons.link_off),
                    onPressed: () => links.tx.containsKey(p.id)
                        ? repo.unlinkTx(p.id)
                        : repo.unlinkPayee(
                            LoanLinkSet.keyOf(p.merchant, p.upiId),
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

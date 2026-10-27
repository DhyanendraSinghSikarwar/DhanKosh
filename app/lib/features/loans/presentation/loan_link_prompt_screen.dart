import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';

/// Asked after a payment is categorised as an EMI: count it towards one of
/// the loans? (FR-15-09). Route `/loan-link/:txId`; "Not now" just closes.
class LoanLinkPromptScreen extends ConsumerWidget {
  /// Creates the prompt for transaction [txId].
  const LoanLinkPromptScreen({required this.txId, super.key});

  /// Ledger row to link.
  final int txId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = [
      for (final l
          in ref.watch(loansStateProvider).value?.loans ?? const <Loan>[])
        if (l.accountId != null) l,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Link to a loan?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Count this EMI towards a loan.'),
          const SizedBox(height: 8),
          if (loans.isEmpty) const Text('No loan accounts yet.'),
          for (final l in loans)
            ListTile(
              key: Key('prompt-loan-${l.accountId}'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.name),
              onTap: () async {
                await ref
                    .read(loanLinkRepositoryProvider)
                    .linkTx(txId, l.accountId!);
                if (context.mounted) await Navigator.maybePop(context);
              },
            ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('prompt-not-now'),
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }
}

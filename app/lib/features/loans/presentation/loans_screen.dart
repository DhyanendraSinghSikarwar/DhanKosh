import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/features/loans/presentation/loan_card.dart';
import 'package:hisaab/features/loans/presentation/loan_form_sheet.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Loans: detected and hand-entered loans (FR-15-01..07, FR-15-11).
/// Route `/loans`.
class LoansScreen extends ConsumerWidget {
  /// Creates the screen.
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loansStateProvider);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      floatingActionButton: FloatingActionButton(
        key: const Key('loans-add'),
        tooltip: 'Add loan',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const LoanFormSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load loans')),
        data: (s) {
          if (s.loans.isEmpty && s.dismissed.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No loans yet',
              hint: 'EMIs are detected from payments. Or add one.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              for (final l in s.loans) ...[
                LoanCard(
                  key: Key('loan-${l.key}'),
                  loan: l,
                  masked: masked,
                  onTap: () =>
                      context.push('/loans/${Uri.encodeComponent(l.key)}'),
                ),
                const SizedBox(height: 12),
              ],
              if (s.dismissed.isNotEmpty) ...[
                Text(
                  'Not a loan',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final p in s.dismissed)
                  ListTile(
                    key: Key('dismissed-$p'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(p),
                    trailing: TextButton(
                      onPressed: () => ref
                          .read(loanLinkRepositoryProvider)
                          .undismissPayee(p),
                      child: const Text('Undo'),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

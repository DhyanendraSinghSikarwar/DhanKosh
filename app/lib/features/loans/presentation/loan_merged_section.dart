import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/loans_providers.dart';

/// Accounts merged into a loan, each with Unmerge (FR-15-12).
class LoanMergedSection extends ConsumerWidget {
  /// Creates the section for loan account [accountId].
  const LoanMergedSection({required this.accountId, super.key});

  /// The loan's account id.
  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merged =
        ref.watch(mergedLoanAccountsProvider(accountId)).value ?? const [];
    if (merged.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Merged', style: Theme.of(context).textTheme.titleSmall),
        for (final a in merged)
          ListTile(
            key: Key('merged-${a.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(a.nickname ?? a.bankName),
            subtitle: a.last4.isEmpty ? null : Text('••${a.last4}'),
            trailing: TextButton(
              key: Key('unmerge-${a.id}'),
              onPressed: () async {
                await ref.read(loanMergeActionsProvider).unmerge(a.id);
                ref
                  ..invalidate(mergedLoanAccountsProvider(accountId))
                  ..invalidate(loanDuplicatesProvider);
              },
              child: const Text('Unmerge'),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

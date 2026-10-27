import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/loans_providers.dart';

/// "Looks like the same loan" suggestions with Merge and Not duplicates
/// (FR-15-12). Shows nothing when there are none.
class LoanDuplicatesSection extends ConsumerWidget {
  /// Creates the section.
  const LoanDuplicatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dups = ref.watch(loanDuplicatesProvider).value ?? const [];
    if (dups.isEmpty) return const SizedBox.shrink();
    final actions = ref.read(loanMergeActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Possible duplicates',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final d in dups)
          Card(
            key: Key('dup-${d.key}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d.from.name} and ${d.into.name} look like the same '
                      'loan.'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: Key('dup-no-${d.key}'),
                        onPressed: () async {
                          await actions.notDuplicates(d);
                          ref.invalidate(loanDuplicatesProvider);
                        },
                        child: const Text('Not duplicates'),
                      ),
                      FilledButton(
                        key: Key('dup-merge-${d.key}'),
                        onPressed: () async {
                          await actions.merge(d);
                          ref.invalidate(loanDuplicatesProvider);
                        },
                        child: const Text('Merge'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

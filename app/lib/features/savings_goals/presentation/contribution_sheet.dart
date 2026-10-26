import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/goals_providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/savings_goals/domain/goal.dart';

/// Records money the user set aside for a goal (FR-36-02). A note only;
/// nothing moves.
class ContributionSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [goal].
  const ContributionSheet({required this.goal, super.key});

  /// Goal receiving the contribution.
  final Goal goal;

  @override
  ConsumerState<ContributionSheet> createState() => _State();
}

class _State extends ConsumerState<ContributionSheet> {
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minor = parseMoney(_amount.text)?.minor;
    if (minor == null || minor <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    await ref.read(goalRepositoryProvider).addContribution(
          widget.goal.id,
          minor,
          Ist.dayOf(DateTime.now().millisecondsSinceEpoch),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add to ${widget.goal.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              key: const Key('contrib-amount'),
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('contrib-save'),
              onPressed: _save,
              child: const Text('Add'),
            ),
          ],
        ),
      );
}

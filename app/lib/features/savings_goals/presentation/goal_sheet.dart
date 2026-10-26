import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/goals_providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/savings_goals/domain/goal.dart';

/// Add or edit a goal (FR-36-01).
class GoalSheet extends ConsumerStatefulWidget {
  /// Creates the sheet; [goal] edits.
  const GoalSheet({this.goal, super.key});

  /// Goal to edit; null adds.
  final Goal? goal;

  @override
  ConsumerState<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<GoalSheet> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  int? _day;
  String? _error;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _name = TextEditingController(text: g?.name ?? '');
    final t = g?.targetMinor;
    _target = TextEditingController(
      text: t == null ? '' : (t % 100 == 0 ? '${t ~/ 100}' : '${t / 100}'),
    );
    _day = g?.targetDay;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = Ist.dateOf(DateTime.now().millisecondsSinceEpoch);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day == null
          ? now.add(const Duration(days: 180))
          : DateTime.utc(1970).add(Duration(days: _day!)),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) {
      setState(() {
        _day = DateTime.utc(picked.year, picked.month, picked.day)
            .difference(DateTime.utc(1970))
            .inDays;
      });
    }
  }

  Future<void> _save() async {
    final minor = parseMoney(_target.text)?.minor;
    final d = GoalDraft(
      name: _name.text.trim(),
      targetMinor: minor ?? 0,
      targetDay: _day,
    );
    final err = minor == null ? 'Enter a target amount' : d.validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final repo = ref.read(goalRepositoryProvider);
    if (widget.goal == null) {
      await repo.addGoal(d);
    } else {
      await repo.updateGoal(widget.goal!.id, d);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(goalRepositoryProvider).deleteGoal(widget.goal!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.goal == null ? 'Add goal' : 'Edit goal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              key: const Key('goal-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              key: const Key('goal-target'),
              controller: _target,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Target (₹)'),
            ),
            ListTile(
              key: const Key('goal-date'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                day == null
                    ? 'Target date (optional)'
                    : () {
                        final d = DateTime.utc(1970).add(Duration(days: day));
                        return '${d.day}/${d.month}/${d.year}';
                      }(),
              ),
              trailing: day == null
                  ? const Icon(Icons.event_outlined)
                  : IconButton(
                      tooltip: 'Clear date',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _day = null),
                    ),
              onTap: _pickDay,
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('goal-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Row(
              children: [
                if (widget.goal != null)
                  TextButton(
                    key: const Key('goal-delete'),
                    onPressed: _delete,
                    child: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('goal-save'),
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

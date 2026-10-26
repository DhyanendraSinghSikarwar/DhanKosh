import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry to Savings goals (route `/goals`).
class GoalsTile extends StatelessWidget {
  /// Creates the tile.
  const GoalsTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('goals-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.savings_outlined),
        title: const Text('Goals & salary plan'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/goals'),
      );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to Savings goals (route `/goals`).
class GoalsTile extends StatelessWidget {
  /// Creates the tile.
  const GoalsTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('goals-tile'),
        badge: AppIcons.goals,
        title: 'Goals',
        subtitle: 'Savings goals',
        onTap: () => context.push('/goals'),
      );
}

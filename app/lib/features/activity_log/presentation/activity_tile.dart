import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-screen entry to the Activity log.
class ActivityTile extends StatelessWidget {
  /// Creates the tile.
  const ActivityTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('activity-tile'),
        badge: AppIcons.activity,
        title: 'Activity log',
        subtitle: 'What changed and when',
        onTap: () => context.push('/activity'),
      );
}

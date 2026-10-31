import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry for the Alerts screen (F-21), composed in `app/router.dart`.
class AlertsTile extends StatelessWidget {
  /// Creates the tile.
  const AlertsTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('alerts-tile'),
        badge: AppIcons.alerts,
        title: 'Alerts',
        subtitle: 'Bill reminders, new transactions',
        onTap: () => context.push('/settings/alerts'),
      );
}

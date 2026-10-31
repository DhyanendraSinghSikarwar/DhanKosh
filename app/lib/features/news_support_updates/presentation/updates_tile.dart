import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry for "About and updates" (F-31), composed in `app/router.dart`.
class UpdatesTile extends StatelessWidget {
  /// Creates the tile.
  const UpdatesTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('updates-tile'),
        badge: AppIcons.updates,
        title: 'Check for updates',
        subtitle: 'v$appVersion',
        onTap: () => context.push('/settings/updates'),
      );
}

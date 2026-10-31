import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry for Backup & Export (F-24), composed in `app/router.dart`.
class BackupTile extends StatelessWidget {
  /// Creates the tile.
  const BackupTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('backup-tile'),
        badge: AppIcons.backup,
        title: 'Backup',
        subtitle: 'Export and restore',
        onTap: () => context.push('/settings/backup'),
      );
}

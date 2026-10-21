import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry for Backup & Export (F-24), composed in `app/router.dart`.
class BackupTile extends StatelessWidget {
  /// Creates the tile.
  const BackupTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('backup-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.backup_outlined),
        title: const Text('Backup & Export'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/backup'),
      );
}

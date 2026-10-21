import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry for "About and updates" (F-31), composed in `app/router.dart`.
class UpdatesTile extends StatelessWidget {
  /// Creates the tile.
  const UpdatesTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('updates-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline),
        title: const Text('About and updates'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/updates'),
      );
}

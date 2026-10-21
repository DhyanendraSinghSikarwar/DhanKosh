import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry for the Alerts screen (F-21), composed in `app/router.dart`.
class AlertsTile extends StatelessWidget {
  /// Creates the tile.
  const AlertsTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('alerts-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Alerts'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/alerts'),
      );
}

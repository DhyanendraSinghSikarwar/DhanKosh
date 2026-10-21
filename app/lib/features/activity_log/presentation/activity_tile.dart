import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-screen entry to the Activity log.
class ActivityTile extends StatelessWidget {
  /// Creates the tile.
  const ActivityTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('activity-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history),
        title: const Text('Activity log'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/activity'),
      );
}

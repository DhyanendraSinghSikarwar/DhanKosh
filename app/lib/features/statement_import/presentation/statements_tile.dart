import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry to the statements screen; composed in `app/router.dart`.
class StatementsTile extends StatelessWidget {
  /// Creates the tile.
  const StatementsTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('statements-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.description_outlined),
        title: const Text('Statements'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/statements'),
      );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry to the Rules screen; composed in `app/router.dart`.
class RulesTile extends StatelessWidget {
  /// Creates the tile.
  const RulesTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('rules-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.rule_outlined),
        title: const Text('Rules'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/rules'),
      );
}

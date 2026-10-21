import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry for the Forex rates screen (F-23), composed in
/// `app/router.dart`.
class ForexTile extends StatelessWidget {
  /// Creates the tile.
  const ForexTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('forex-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.currency_exchange),
        title: const Text('Forex rates'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/forex'),
      );
}

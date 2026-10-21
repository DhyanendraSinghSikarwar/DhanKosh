import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-screen entry to Security & privacy.
class SecurityTile extends StatelessWidget {
  /// Creates the tile.
  const SecurityTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('security-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.shield_outlined),
        title: const Text('Security & privacy'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/security'),
      );
}

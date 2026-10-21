import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/updates_providers.dart';

/// More-tab entry for "Support DhanKosh" (F-31); hidden when no donation
/// address is configured (FR-31-10).
class SupportTile extends StatelessWidget {
  /// Creates the tile.
  const SupportTile({this.upiId = supportUpiId, super.key});

  /// Donation address; empty hides the tile.
  final String upiId;

  @override
  Widget build(BuildContext context) => upiId.isEmpty
      ? const SizedBox.shrink()
      : ListTile(
          key: const Key('support-tile'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.coffee_outlined),
          title: const Text('Support DhanKosh'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/support'),
        );
}

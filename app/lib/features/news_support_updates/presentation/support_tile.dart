import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

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
      : SettingsRow(
          key: const Key('support-tile'),
          badge: AppIcons.support,
          title: 'Support',
          subtitle: 'Optional UPI tip',
          onTap: () => context.push('/settings/support'),
        );
}

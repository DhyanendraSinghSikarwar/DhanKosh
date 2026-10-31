import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry for the Forex rates screen (F-23), composed in
/// `app/router.dart`.
class ForexTile extends StatelessWidget {
  /// Creates the tile.
  const ForexTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('forex-tile'),
        badge: AppIcons.forex,
        title: 'Forex rates',
        subtitle: 'Manual conversion rates',
        onTap: () => context.push('/settings/forex'),
      );
}

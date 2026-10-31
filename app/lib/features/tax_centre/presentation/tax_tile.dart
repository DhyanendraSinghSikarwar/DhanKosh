import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to the Tax Centre; composed in `app/router.dart`.
class TaxTile extends StatelessWidget {
  /// Creates the tile.
  const TaxTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('tax-tile'),
        badge: AppIcons.tax,
        title: 'Tax centre',
        subtitle: 'Year summary and export',
        onTap: () => context.push('/tax'),
      );
}

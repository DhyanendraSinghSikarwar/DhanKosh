import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to the statements screen; composed in `app/router.dart`.
class StatementsTile extends StatelessWidget {
  /// Creates the tile.
  const StatementsTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('statements-tile'),
        badge: AppIcons.statements,
        title: 'Statements',
        subtitle: 'PDF, Excel, CSV import',
        onTap: () => context.push('/statements'),
      );
}

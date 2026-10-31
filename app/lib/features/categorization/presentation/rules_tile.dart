import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to the Rules screen; composed in `app/router.dart`.
class RulesTile extends StatelessWidget {
  /// Creates the tile.
  const RulesTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('rules-tile'),
        badge: AppIcons.rules,
        title: 'Rules',
        subtitle: 'Automatic categorisation',
        onTap: () => context.push('/rules'),
      );
}

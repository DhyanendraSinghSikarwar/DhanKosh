import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to the Customise screen (F-28).
class CustomiseTile extends StatelessWidget {
  /// Creates the tile.
  const CustomiseTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('customise-tile'),
        badge: AppIcons.customise,
        title: t('Customise'),
        subtitle: 'Theme, sections, text size',
        onTap: () => context.push('/settings/appearance'),
      );
}

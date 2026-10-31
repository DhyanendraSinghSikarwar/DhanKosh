import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to the Language screen (F-29).
class LanguageTile extends StatelessWidget {
  /// Creates the tile.
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('language-tile'),
        badge: AppIcons.language,
        title: t('Language'),
        subtitle: 'App language and packs',
        onTap: () => context.push('/settings/language'),
      );
}

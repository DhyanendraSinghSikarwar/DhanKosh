import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/localization/domain/language.dart';

/// More-tab entry to the Language screen (F-29).
class LanguageTile extends StatelessWidget {
  /// Creates the tile.
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('language-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.language),
        title: Text(t('Language')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/language'),
      );
}

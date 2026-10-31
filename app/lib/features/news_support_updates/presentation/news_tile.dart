import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry for "Market news" (F-31), composed in `app/router.dart`.
class NewsTile extends StatelessWidget {
  /// Creates the tile.
  const NewsTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('news-tile'),
        badge: AppIcons.news,
        title: 'Market news',
        subtitle: 'Headlines for your holdings',
        onTap: () => context.push('/news'),
      );
}

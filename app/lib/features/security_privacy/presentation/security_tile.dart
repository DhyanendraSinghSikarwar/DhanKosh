import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-screen entry to Security & privacy.
class SecurityTile extends StatelessWidget {
  /// Creates the tile.
  const SecurityTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('security-tile'),
        badge: AppIcons.security,
        title: t('Security'),
        subtitle: t('App lock, timeout, screenshots'),
        onTap: () => context.push('/settings/security'),
      );
}

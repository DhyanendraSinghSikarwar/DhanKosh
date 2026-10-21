import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/localization/domain/language.dart';

/// More-tab entry to the Customise screen (F-28).
class CustomiseTile extends StatelessWidget {
  /// Creates the tile.
  const CustomiseTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('customise-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.palette_outlined),
        title: Text(t('Customise')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/appearance'),
      );
}

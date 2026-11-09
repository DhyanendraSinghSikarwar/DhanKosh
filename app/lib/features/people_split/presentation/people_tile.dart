import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/groups_people_providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to People and splits (F-40), composed in `app/router.dart`.
class PeopleTile extends ConsumerWidget {
  /// Creates the tile.
  const PeopleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owed = (ref.watch(peopleProvider).value ?? const [])
        .where((p) => p.balanceMinor != 0)
        .length;
    return SettingsRow(
      key: const Key('people-tile'),
      badge: AppIcons.loans,
      title: t('People and splits'),
      subtitle: owed == 0 ? 'Shared costs and who owes whom' : '$owed open',
      onTap: () => context.push('/people'),
    );
  }
}

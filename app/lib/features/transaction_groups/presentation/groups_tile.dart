import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/groups_people_providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to Groups (F-39), composed in `app/router.dart`.
class GroupsTile extends ConsumerWidget {
  /// Creates the tile.
  const GroupsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(txGroupsProvider).value?.length ?? 0;
    return SettingsRow(
      key: const Key('groups-tile'),
      badge: AppIcons.accounts,
      title: t('Groups'),
      subtitle: n == 0 ? 'Bundle a trip or an event' : '$n groups',
      onTap: () => context.push('/groups'),
    );
  }
}

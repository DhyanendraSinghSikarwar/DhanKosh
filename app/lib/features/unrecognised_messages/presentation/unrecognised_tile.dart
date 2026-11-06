import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/unrecognised_messages/presentation/unrecognised_providers.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry for the review queue (F-38), composed in `app/router.dart`.
class UnrecognisedTile extends ConsumerWidget {
  /// Creates the tile.
  const UnrecognisedTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(freshCountProvider).value ?? 0;
    return SettingsRow(
      key: const Key('unrecognised-tile'),
      badge: AppIcons.diagnostics,
      title: 'Unrecognised messages',
      subtitle: n == 0 ? 'Payments no bank format matched' : '$n to review',
      onTap: () => context.push('/review/unrecognised'),
    );
  }
}

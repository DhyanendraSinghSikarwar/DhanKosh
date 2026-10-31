import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry for the Diagnostic Log (F-35), composed in `app/router.dart`.
class DiagnosticLogTile extends StatelessWidget {
  /// Creates the tile.
  const DiagnosticLogTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('diagnostic-log-tile'),
        badge: AppIcons.diagnostics,
        title: 'Diagnostic log',
        subtitle: 'Counts only, never messages',
        onTap: () => context.push('/settings/logs'),
      );
}

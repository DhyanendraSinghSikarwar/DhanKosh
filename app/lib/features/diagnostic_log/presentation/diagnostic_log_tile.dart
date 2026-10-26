import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry for the Diagnostic Log (F-35), composed in `app/router.dart`.
class DiagnosticLogTile extends StatelessWidget {
  /// Creates the tile.
  const DiagnosticLogTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('diagnostic-log-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.bug_report_outlined),
        title: const Text('Diagnostic log'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/logs'),
      );
}

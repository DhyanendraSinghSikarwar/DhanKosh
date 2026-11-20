import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/activity_log/domain/inbox_logic.dart';
import 'package:hisaab/features/activity_log/presentation/activity_log_screen.dart';
import 'package:hisaab/features/dashboard_home/domain/home_attention.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// The bell's Inbox (FR-22-19): only what needs attention and what went wrong.
/// Counts of messages read and sync times are not here; they stay in the
/// Activity log.
class InboxScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// Last-seen time when the screen opened; problems newer than it show a dot.
  int _seen = 1 << 62;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_markSeen));
  }

  Future<void> _markSeen() async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final before = await repo.read(SettingKeys.activityLastSeen);
      if (mounted) setState(() => _seen = before);
      await repo.write(
        SettingKeys.activityLastSeen,
        DateTime.now().millisecondsSinceEpoch,
      );
    } on Object {
      // Settings unavailable: no unread dots.
    }
  }

  @override
  Widget build(BuildContext context) {
    final attention = ref.watch(homeAttentionProvider);
    final problems = ref.watch(inboxProblemsProvider).take(30).toList();
    return Scaffold(
      appBar: AppBar(title: Text(t('Inbox'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (attention.isEmpty && problems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                key: const Key('inbox-empty'),
                children: [
                  const Icon(Icons.check_circle_outline, size: 40),
                  const SizedBox(height: 8),
                  Text(t('All clear')),
                ],
              ),
            ),
          if (attention.isNotEmpty) ...[
            Text(
              t('Needs attention'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            AppCard(
              key: const Key('inbox-attention'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final i in attention)
                    ListTile(
                      key: Key('inbox-attn-${i.kind.name}'),
                      leading: Icon(_icon(i.kind)),
                      title: Text(i.title),
                      subtitle: Text(i.detail),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(i.route),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (problems.isNotEmpty) ...[
            Text(
              t('Problems'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            AppCard(
              key: const Key('inbox-problems'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in problems)
                    ActivityEntryRow(e, unread: InboxLogic.isUnread(e, _seen)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('inbox-open-log'),
              onPressed: () => context.push('/activity'),
              icon: const Icon(Icons.history),
              label: Text(t('Open activity log')),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(AttentionKind k) => switch (k) {
        AttentionKind.duplicates => Icons.flag_outlined,
        AttentionKind.bill => Icons.receipt_long_outlined,
        AttentionKind.statement => Icons.lock_outline,
        AttentionKind.card => Icons.credit_card,
        AttentionKind.update => Icons.system_update_outlined,
      };
}

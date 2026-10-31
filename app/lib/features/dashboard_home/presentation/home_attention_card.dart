import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_attention.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// Duplicates, bills, statements and cards that need a look; each row opens
/// its screen and the block is hidden when empty (FR-17-25).
class HomeAttentionCard extends ConsumerWidget {
  /// Creates the block.
  const HomeAttentionCard({super.key});

  static AppIcon _icon(AttentionKind k) => switch (k) {
        AttentionKind.duplicates =>
          const AppIcon(Icons.flag_outlined, AppIcons.amber),
        AttentionKind.bill => AppIcons.bills,
        AttentionKind.statement => AppIcons.security,
        AttentionKind.card => AppIcons.cards,
        AttentionKind.update => AppIcons.updates,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeAttentionProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      key: const Key('home_attention'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader('Needs attention'),
          for (final (n, i) in items.indexed)
            InkWell(
              key: Key('attn_${i.kind.name}'),
              onTap: () => context.push(i.route),
              child: IconAmountRow(
                icon: _icon(i.kind),
                title: i.title,
                subtitle: i.detail,
                divider: n < items.length - 1,
                trailing: i.dismissVersion == null
                    ? Text('›', style: MockText.body(context, color: muted))
                    : IconButton(
                        key: const Key('attn_update_dismiss'),
                        tooltip: 'Dismiss',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => unawaited(
                          ref.read(dismissUpdateNoticeProvider)(
                            i.dismissVersion!,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/dashboard_home/domain/home_attention.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Duplicates, bills, statements and cards that need a look; each row opens
/// its screen and the block is hidden when empty (FR-17-25).
class HomeAttentionCard extends ConsumerWidget {
  /// Creates the block.
  const HomeAttentionCard({super.key});

  static IconData _icon(AttentionKind k) => switch (k) {
        AttentionKind.duplicates => Icons.flag_outlined,
        AttentionKind.bill => Icons.event_outlined,
        AttentionKind.statement => Icons.lock_outline,
        AttentionKind.card => Icons.credit_card,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeAttentionProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final warn = theme.extension<SemanticColors>()?.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        key: const Key('home_attention'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Needs attention', style: theme.textTheme.titleSmall),
            for (final i in items)
              ListTile(
                key: Key('attn_${i.kind.name}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(_icon(i.kind), color: warn),
                title: Text(i.title),
                subtitle: Text(i.detail),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(i.route),
              ),
          ],
        ),
      ),
    );
  }
}

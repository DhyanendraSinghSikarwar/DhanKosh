import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// Insights: notable changes and warnings as a swipeable carousel; dismissal
/// lasts for the session only (FR-17-10, FR-17-21).
class HomeInsightsCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const HomeInsightsCard({super.key});

  @override
  ConsumerState<HomeInsightsCard> createState() => _HomeInsightsCardState();
}

class _HomeInsightsCardState extends ConsumerState<HomeInsightsCard> {
  final _dismissed = <String>{};
  String? _open;

  static String _tag(Tone t) => switch (t) {
        Tone.warn => 'Heads up',
        Tone.good => 'Good news',
        Tone.info => 'Pattern',
      };

  static AppIcon _icon(Tone t) => switch (t) {
        Tone.warn => const AppIcon(Icons.warning_amber_rounded, AppIcons.amber),
        Tone.good => const AppIcon(Icons.trending_up, AppIcons.mint),
        Tone.info => AppIcons.insight,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(analyticsViewProvider).value?.insights ?? const [];
    final shown = [
      for (final i in all)
        if (!_dismissed.contains(i.title)) i,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final open = shown.where((i) => i.title == _open).firstOrNull;
    final scheme = theme.colorScheme;
    return AppCard(
      key: const Key('home_insights'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader('Insights'),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, n) {
                final i = shown[n];
                final on = i.title == _open;
                return InkWell(
                  key: Key('home_insight_${i.title}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _open = on ? null : i.title),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: on
                          ? scheme.primaryContainer
                          : scheme.surfaceContainer,
                      border: Border.all(
                        color: on ? scheme.primary : scheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      i.title,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                );
              },
            ),
          ),
          if (open != null)
            Container(
              key: const Key('home_insight_detail'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBadge(_icon(open.tone), size: 22),
                      const SizedBox(width: 6),
                      Text(_tag(open.tone), style: MockText.small(context)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(open.detail, style: MockText.body(context)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _dismissed.add(open.title);
                        _open = null;
                      }),
                      child: const Text('Dismiss'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

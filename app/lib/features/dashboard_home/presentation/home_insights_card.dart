import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

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

  static String _tag(Tone t) => switch (t) {
        Tone.warn => 'Heads up',
        Tone.good => 'Good news',
        Tone.info => 'Pattern',
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
    return AppCard(
      key: const Key('home_insights'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Insights · ${shown.length}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          SizedBox(
            height: 124,
            child: PageView(
              padEnds: false,
              controller: PageController(viewportFraction: 0.86),
              children: [
                for (final i in shown)
                  Padding(
                    key: Key('home_insight_${i.title}'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tag(i.tone),
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          i.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          i.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _dismissed.add(i.title)),
                            child: const Text('Dismiss'),
                          ),
                        ),
                      ],
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

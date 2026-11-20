import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/credit_cards/domain/card_view.dart';
import 'package:hisaab/features/credit_cards/presentation/card_due_format.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// One bar for a card's limit (FR-14-30): green is what is left, orange the
/// unbilled spends, red the billed amount, each in proportion, with the
/// amounts underneath.
class CardLimitBar extends StatelessWidget {
  /// Creates the bar for [view]; draws nothing without a limit.
  const CardLimitBar({required this.view, required this.masked, super.key});

  /// The card.
  final CardView view;

  /// Hide the amounts.
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final bar = view.limitBar;
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>() ??
        (theme.brightness == Brightness.dark
            ? SemanticColors.dark
            : SemanticColors.light);
    const orange = Color(0xFFF08A24);
    final parts = <(int?, Color, String)>[
      (bar.left, sem.income, t('Left')),
      (bar.unbilled, orange, t('Unbilled')),
      (bar.billed, sem.expense, t('Billed')),
    ];
    final track = theme.colorScheme.surfaceContainerHighest;
    final segments = [
      for (final (v, c, _) in parts)
        if (v != null && v > 0) (v, c),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          key: Key('home_card_bar_${view.card.id}'),
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: segments.isEmpty
                ? ColoredBox(color: track)
                : Row(
                    children: [
                      for (final (v, c) in segments)
                        Expanded(
                          flex: v,
                          child: ColoredBox(color: c),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (v, c, label) in parts)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration:
                              BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MockText.small(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      v == null ? '—' : cardCompact(v, masked: masked),
                      key: Key('home_card_bar_${label}_${view.card.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MockText.body(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

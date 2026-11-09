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
    if (bar == null) return const SizedBox.shrink();
    final sem = Theme.of(context).extension<SemanticColors>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? SemanticColors.dark
            : SemanticColors.light);
    const orange = Color(0xFFF08A24);
    final parts = [
      (bar.left, sem.income, t('Left')),
      (bar.unbilled, orange, t('Unbilled')),
      (bar.billed, sem.expense, t('Billed')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          key: Key('home_card_bar_${view.card.id}'),
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (final (v, c, _) in parts)
                  if (v > 0) Expanded(flex: v, child: ColoredBox(color: c)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          children: [
            for (final (v, c, label) in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$label ${cardCompact(v, masked: masked)}',
                    style: MockText.small(context),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

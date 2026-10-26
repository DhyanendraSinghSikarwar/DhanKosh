import 'package:flutter/material.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/analytics/domain/insight_extras.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Formats paise for display.
typedef ExtraMoneyText = String Function(int minor);

Widget _card(BuildContext context, Key key, String title, Widget child) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );

Widget _line(BuildContext context, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );

/// Income by source for the period (FR-18-24).
class IncomeSourcesCard extends StatelessWidget {
  /// Creates the card.
  const IncomeSourcesCard({
    required this.sources,
    required this.money,
    super.key,
  });

  final List<IncomeSource> sources;
  final ExtraMoneyText money;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    return _card(
      context,
      const Key('insight_income_sources'),
      'Income by source',
      Column(
        children: [
          for (final s in sources)
            _line(context, '${s.label} (${s.count})', money(s.totalMinor)),
        ],
      ),
    );
  }
}

/// Detected subscriptions with the monthly total (FR-18-25).
class SubscriptionsCard extends StatelessWidget {
  /// Creates the card.
  const SubscriptionsCard({
    required this.lines,
    required this.money,
    super.key,
  });

  final List<SubscriptionLine> lines;
  final ExtraMoneyText money;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return _card(
      context,
      const Key('insight_subscriptions'),
      'Subscriptions',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${money(InsightExtras.monthlyTotal(lines))} / month',
            key: const Key('subscriptions_total'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final l in lines) _line(context, l.name, money(l.monthlyMinor)),
        ],
      ),
    );
  }
}

/// Credit utilisation per card with band colours (FR-18-26).
class CardUtilisationCard extends StatelessWidget {
  /// Creates the card.
  const CardUtilisationCard({
    required this.cards,
    required this.money,
    super.key,
  });

  final List<CardUtil> cards;
  final ExtraMoneyText money;

  static Color bandColor(BuildContext context, UtilBand b) {
    final c = Theme.of(context).extension<SemanticColors>();
    return switch (b) {
      UtilBand.good => c?.income ?? Colors.green,
      UtilBand.watch => c?.warning ?? Colors.amber,
      UtilBand.high => c?.expense ?? Colors.red,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return _card(
      context,
      const Key('insight_utilisation'),
      'Credit utilisation',
      Column(
        children: [
          for (final c in cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  _line(
                    context,
                    c.name,
                    '${money(c.usedMinor)} of ${money(c.limitMinor)}',
                  ),
                  LinearProgressIndicator(
                    key: Key('util_bar_${c.name}'),
                    value: (c.percent / 100).clamp(0, 1).toDouble(),
                    color: bandColor(context, c.band),
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${c.percent}%',
                      key: Key('util_pct_${c.name}'),
                      style: Theme.of(context).textTheme.bodySmall,
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

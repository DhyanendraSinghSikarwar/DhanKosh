import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/features/credit_cards/domain/card_insights.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cards_providers.g.dart';

// F-14 presentation wiring on top of the Phase 3 data layer.

/// Cards that have something to show: a due, an amount or a limit (FR-14-12).
@riverpod
Stream<List<CardLimit>> activeCards(Ref ref) async* {
  await for (final cards in ref.watch(cardDueServiceProvider).watchCards()) {
    yield [
      for (final c in cards)
        if (c.owedMinor > 0 ||
            c.dueDay != null ||
            (c.unbilledMinor ?? 0) > 0 ||
            c.limitMinor != null)
          c,
    ];
  }
}

/// Cycle spend, statement history and late flag of one card (FR-14-18..22).
@riverpod
Future<CardInsights> cardInsights(Ref ref, int cardId) async {
  // Rebuild whenever any card figure changes.
  await ref.watch(activeCardsProvider.future);
  final r = await ref.watch(cardDueServiceProvider).insights(cardId);
  return r;
}

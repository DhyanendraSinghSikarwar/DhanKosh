import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/home_cards_providers.dart';

/// Days (UTC midnight) a credit-card bill is due, for the Bills calendar
/// dots (FR-14-28, FR-12-09).
final cardDueDatesProvider = Provider<Set<DateTime>>((ref) {
  final out = <DateTime>{};
  for (final v in ref.watch(homeCardsProvider)) {
    final d = v.card.dueDay;
    if (d == null || (v.dueMinor <= 0 && !v.card.paid)) continue;
    out.add(DateTime.utc(1970).add(Duration(days: d)));
  }
  return out;
});

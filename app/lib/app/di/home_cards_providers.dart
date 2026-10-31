import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/cards_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/credit_cards/domain/card_matcher.dart';
import 'package:hisaab/features/credit_cards/domain/card_view.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_cards_providers.g.dart';

// Credit-card views for Home and the card page (F-14, F-17): the card
// figures, the user's limit override and the account's Book.

/// Limit overrides by card key (FR-14-26).
final cardLimitOverridesProvider = StreamProvider<Map<String, int>>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(cardLimitOverridesKey)
      .map(CardLimitOverrides.parse),
);

final _usageProvider = StreamProvider<Map<int, AccountUsage>>(
  (ref) => ref.watch(accountRepositoryProvider).watchVisible().map(
        (list) => {for (final a in list) a.id: a.usage},
      ),
);

/// Every active card, whatever the Book (FR-14-24).
final allCardViewsProvider = Provider<List<CardView>>((ref) {
  final cards = ref.watch(activeCardsProvider).value ?? const [];
  final usage = ref.watch(_usageProvider).value ?? const {};
  final limits = ref.watch(cardLimitOverridesProvider).value ?? const {};
  return [
    for (final c in cards)
      CardView(
        card: c,
        usage: usage[c.id] ?? AccountUsage.personal,
        limitOverrideMinor: limits[CardMatcher.cardKey(c.bankName, c.last4)],
      ),
  ];
});

/// Cards of the shared Book (FR-14-25).
final homeCardsProvider = Provider<List<CardView>>((ref) {
  final book = ref.watch(bookProvider);
  return [
    for (final v in ref.watch(allCardViewsProvider))
      if (book == Book.all ||
          (book == Book.personal && v.usage == AccountUsage.personal) ||
          (book == Book.business && v.usage == AccountUsage.business))
        v,
  ];
});

/// One card by account id, null when unknown.
@riverpod
CardView? cardView(Ref ref, int id) =>
    ref.watch(allCardViewsProvider).where((v) => v.card.id == id).firstOrNull;

/// Latest transactions on a card (FR-14-24).
@riverpod
Stream<List<LedgerTx>> cardTransactions(Ref ref, int id) => ref
    .watch(transactionRepositoryProvider)
    .watch(LedgerFilter(accountId: id), limit: 6);

/// Writes the user's limit override; null or the statement's own value
/// clears it (FR-14-26).
Future<void> saveCardLimitOverride(
  WidgetRef ref,
  CardView v,
  int? limitMinor,
) async {
  final repo = ref.read(settingsRepositoryProvider);
  final key = CardMatcher.cardKey(v.card.bankName, v.card.last4);
  final map = CardLimitOverrides.parse(await repo.read(cardLimitOverridesKey));
  if (limitMinor == null || limitMinor == v.card.limitMinor) {
    map.remove(key);
  } else {
    map[key] = limitMinor;
  }
  await repo.write(cardLimitOverridesKey, CardLimitOverrides.encode(map));
}

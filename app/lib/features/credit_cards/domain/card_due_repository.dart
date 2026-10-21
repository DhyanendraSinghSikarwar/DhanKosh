import 'package:hisaab/features/credit_cards/domain/card_models.dart';

/// Recorded card notices and manual overrides (FR-14-06, FR-14-07).
abstract interface class CardDueRepository {
  /// Stores [n] under its key (FR-14-06). A row is skipped when the key exists
  /// and (it is a payment, the existing row has a total, or [n] has none).
  /// Returns true when a row was inserted or replaced.
  Future<bool> recordNotice(NewCardNotice n);

  /// All notices as position inputs.
  Future<List<CardRow>> notices();

  /// Stream of [notices].
  Stream<List<CardRow>> watchNotices();

  /// Override of [cardKey], or null.
  Future<CardOverride?> overrideFor(String cardKey);

  /// All overrides by card key.
  Stream<Map<String, CardOverride>> watchOverrides();

  /// Saves an override (replaces any for the card).
  Future<void> saveOverride(CardOverride o);

  /// Drops the override of [cardKey].
  Future<void> clearOverride(String cardKey);

  /// Deletes notices older than [beforeMs] (120 day prune).
  Future<int> pruneNotices(int beforeMs);
}

/// Paid marks per `cardId|dueEpochDay` (FR-14-09). Stores state only; never
/// the ledger.
abstract interface class CardPaidStore {
  /// Marks the bill with [dueEpochDay] of card [cardId] paid.
  Future<void> markPaid(int cardId, int dueEpochDay);

  /// Reverses [markPaid].
  Future<void> undoPaid(int cardId, int dueEpochDay);

  /// Entries (`cardId|dueEpochDay`).
  Stream<Set<String>> watchPaid();

  /// Entry key for [cardId] and [dueEpochDay].
  static String key(int cardId, int dueEpochDay) => '$cardId|$dueEpochDay';
}

/// Card movements from the ledger (FR-14-17), read only.
abstract interface class CardFlowSource {
  /// Movements of [accountId] (and accounts merged into it) since [fromMs],
  /// oldest first, with a rupee value and not duplicates.
  Future<List<CardFlow>> flowSince(int accountId, int fromMs);
}
